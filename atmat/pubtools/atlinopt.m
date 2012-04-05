function [lindata, varargout] = atlinopt(RING,DP,varargin)
%ATLINOPT			performs linear analysis of the COUPLED lattices
%
% LinData = ATLINOPT(RING,DP,REFPTS) is a MATLAB structure array with fields
%    
%   ElemIndex   - ordinal position in the RING 
%   SPos        - longitudinal position [m]
%   ClosedOrbit - closed orbit column vector with 
%                 components x, px, y, py (momentums, NOT angles)						
%   Dispersion  - dispersion orbit position vector with 
%                 components eta_x, eta_prime_x, eta_y, eta_prime_y
%                 calculated with respect to the closed orbit with 
%                 momentum deviation DP. Only if chromaticity is required.
%   M44         - 4x4 transfer matrix M from the beginning of RING
%                 to the entrance of the element for specified DP [2]
%   A           - 2x2 matrix A in [3]
%   B           - 2x2 matrix B in [3]
%   C           - 2x2 matrix C in [3]			
%   gamma       - gamma parameter of the transformation to eigenmodes 
%   mu          - [ mux, muy] horizontal and vertical betatron phase
%   beta        - [betax, betay] vector
%   alpha       - [alphax, alphay] vector
%
%   All values are specified at the entrance of each element specified in REFPTS. 
%   REFPTS is an array of increasing indexes that  select elements 
%   from the range 1 to length(LINE)+1. 
%   See further explanation of REFPTS in the 'help' for FINDSPOS 
%
% [LinData,NU] = LINOPT() returns a vector of linear tunes
%   [nu_u , nu_v] for two normal modes of linear motion [1] 
%
% [LinData,NU, KSI] = LINOPT() returns a vector of chromaticities ksi = d(nu)/(dP/P)
%   [ksi_u , ksi_v] - derivatives of [nu_u , nu_v] 
%
% LinData = LINOPT(RING,DP,REFPTS,ORBITIN) does not search for closed orbit.
%		instead ORBITIN is used
%
% Difference with linopt: Fractional tunes 0<=tune<1
%			  Dispersion output (if chromaticity is required)
%			  Alpha output
%			  Phase advance output
%			  Option to skip closed orbit search
%
% See also ATREADBETA ATX ATMODUL FINDSPOS TWISSRING TUNECHROM
%
%   [1] D.Edwars,L.Teng IEEE Trans.Nucl.Sci. NS-20, No.3, p.885-888, 1973
%   [2] E.Courant, H.Snyder
%   [3] D.Sagan, D.Rubin Phys.Rev.Spec.Top.-Accelerators and beams, vol.2 (1999)

 
global NUMDIFPARAMS

if nargin >= 3
   REFPTS=varargin{1};
else
   REFPTS= 1;
end

NR=length(REFPTS);
  

spos = findspos(RING,REFPTS);
[M44, MS, orb] = findm44(RING,DP,REFPTS,varargin{2:end});

% Calculate A,B,C, gamma at the first element
M =M44(1:2,1:2);
N =M44(3:4,3:4);
m =M44(1:2,3:4);
n =M44(3:4,1:2);

% 2-by-2 symplectic matrix
S = [0 1; -1 0];
H = m + S*n'*S';
t = trace(M-N);

g = sqrt(1 + sqrt(t*t/(t*t+4*det(H))))/sqrt(2);
G = diag([g g]);
C = -H*sign(t)/(g*sqrt(t*t+4*det(H)));
A = G*G*M  -  G*(m*S*C'*S' + C*n) + C*N*S*C'*S';
B = G*G*N  +  G*(S*C'*S'*m + n*C) + S*C'*S'*M*C;

lindata = struct('ElemIndex',num2cell(REFPTS),'SPos',num2cell(spos),...
    'ClosedOrbit',num2cell(orb,1),'M44',squeeze(num2cell(MS,[1 2]))');

MSA=zeros(2,2,NR);
MSB=zeros(2,2,NR);
%gamma=zeros(NR);
%AL=zeros(2,2,NR);
%BL=zeros(2,2,NR);
%CL=zeros(2,2,NR);
for i=1:NR
    M12 =MS(1:2,1:2,i);
    N12 =MS(3:4,3:4,i);
    m12 =MS(1:2,3:4,i);
    n12 =MS(3:4,1:2,i);
   
    g2 = sqrt(det(n12*C+G*N12));
    E12 = (G*M12-m12*S*C'*S')/g2;
    F12 = (n12*C+G*N12)/g2;

    MSA(:,:,i)=E12;
    MSB(:,:,i)=F12;
%     gamma(i)=g2;
%     CL(:,:,i)=(M12*C+G*m12)*S*F12'*S';
%     AL(:,:,i)=E12*A*S*E12'*S';
%     BL(:,:,i)=F12*B*S*F12'*S';
    lindata(i).gamma=g2;
    lindata(i).C=(M12*C+G*m12)*S*F12'*S';
    lindata(i).A=E12*A*S*E12'*S';
    lindata(i).B=F12*B*S*F12'*S';
end

[BX,AX,MX]=lop(MSA,A);
[BY,AY,MY]=lop(MSB,B);

%tunes = [MX(end),MY(end)]/2/pi;

% lindata = struct('ElemIndex',num2cell(REFPTS),'SPos',num2cell(spos),...
%     'ClosedOrbit',num2cell(orb,1),'M44',squeeze(num2cell(MS,[1 2]))',...
%     'gamma', num2cell(gamma,2)',...
%     'C', squeeze(num2cell(CL,1:2))',...
%     'A', squeeze(num2cell(AL,1:2))',...
%     'B', squeeze(num2cell(BL,1:2))',...
%     'beta', num2cell([BX,BY],2)',...
%     'alpha', num2cell([AX,AY],2)',...
%     'mu', num2cell([MX,MY],2)');
xx=num2cell([BX BY],2);
[lindata.beta]=deal(xx{:});
xx=num2cell([AX AY],2);
[lindata.alpha]=deal(xx{:});
xx=num2cell([MX MY],2);
[lindata.mu]=deal(xx{:});

if nargout >= 2
   cos_mu_x = trace(A)/2;
   cos_mu_y = trace(B)/2;
   tns = acos([cos_mu_x cos_mu_y])/2/pi;
   if A(1,2) < 0, tns(1)=1-tns(1); end
   if B(1,2) < 0, tns(2)=1-tns(2); end
   varargout{1}=tns;
end

if nargout >= 3
    if isfield(NUMDIFPARAMS,'DPStep')
        dDP = NUMDIFPARAMS.DPStep';
    else
        dDP =  1e-6;
    end
    % Calculate tunes for DP+dDP
    if REFPTS(1) == 1
       orbP = findorbit4(RING,DP+0.5*dDP,REFPTS);
       orbM = findorbit4(RING,DP-0.5*dDP,REFPTS);
       DISPERSION = num2cell((orbP-orbM)/dDP,1);
    else
       orbP = findorbit4(RING,DP+0.5*dDP,[1 REFPTS]);
       orbM = findorbit4(RING,DP-0.5*dDP,[1 REFPTS]);
       DISPERSION = num2cell((orbP(:,2:end)-orbM(:,2:end))/dDP,1);
    end
    [LD, tunesP] = atlinopt(RING,DP+0.5*dDP,1,[orbP(:,1);DP+0.5*dDP;0]);
    [LD, tunesM] = atlinopt(RING,DP-0.5*dDP,1,[orbM(:,1);DP-0.5*dDP;0]);
    varargout{2} = (tunesP - tunesM)/dDP;
    
    [lindata.Dispersion] = deal(DISPERSION{:});
end

function [beta,alpha]=nufof(T)
%cosmu = (T(1,1)+T(2,2))/2;
sinmu = sign(T(1,2))*sqrt(-T(1,2)*T(2,1)-(T(1,1)-T(2,2))^2/4);
alpha = (T(1,1)-T(2,2))/2/sinmu;
beta = T(1,2)/sinmu;

function UP = BetatronPhaseUnwrap(P)
% unwrap negative jumps in betatron
    JUMPS = [0; diff(P)] < -1.e-5;
    UP = P+cumsum(JUMPS)*pi;

function [beta,alpha,phase]=lop(MS,A0)
[bx,ax]=nufof(A0);
bbb=squeeze(MS(1,2,:));
aaa=squeeze(MS(1,1,:))*bx-bbb*ax;

beta = (aaa.^2 + bbb.^2)/bx;
alpha = -(aaa.*squeeze(MS(2,1,:)*bx-MS(2,2,:)*ax) + bbb.*squeeze(MS(2,2,:)))/bx;
%phase = atan2(bbb,aaa);
phase = atan(bbb./aaa);
phase = BetatronPhaseUnwrap(phase);