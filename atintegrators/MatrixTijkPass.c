/* MatrixTijkPass.c 
   Accelerator Toolbox 
*/


#include "atelem.c"
#include "atlalib.c"

struct elem {
    double Length;
    double *M66;
    double *Tijk;
    /* Optional fields */
    double *R1;
    double *R2;
    double *T1;
    double *T2;
};

static void ATmultTijk(double *r, const double* T)
/*	multiplies 6-component column vector r by 6x6x6 tensor T:
 * as in r_i=Sum_j(Sum_k(Tijk*r_j*r_k)) 
  The result is stored in the memory area of r !!!
*/

{   int i,j,k;
    double temp[6];
    
    for(i=0;i<6;i++)
    {	temp[i]=0;
        for(j=0;j<6;j++)
        {
            for(k=0;k<6;k++)
                temp[i]+=T[i+j*6+k*36]*r[j]*r[k];
        }
    }
  	for(i=0;i<6;i++)
	r[i]+=temp[i];
} 

void MatrixTijkPass(double *r, const double *M66, const double *Tijk,
        const double *T1, const double *T2,
        const double *R1, const double *R2, int num_particles)

{
    double *r6;
    int c;
    
    for (c = 0; c<num_particles; c++) {	/*Loop over particles  */
        r6 = r+c*6;
        if (!atIsNaN(r6[0])) {
            /* Misalignment at entrance */
            if (T1) ATaddvv(r6, T1);
            if (R1) ATmultmv(r6, R1);
            ATmultmv(r6, M66);
            ATmultTijk(r6,Tijk);
            /* Misalignment at exit */
            if (R2) ATmultmv(r6, R2);
            if (T2) ATaddvv(r6, T2);
        }
	}
}

#if defined(MATLAB_MEX_FILE) || defined(PYAT)
ExportMode struct elem *trackFunction(const atElem *ElemData,struct elem *Elem,
        double *r_in, int num_particles, struct parameters *Param)
{
    if (!Elem) {
        double Length=0.0, *M66, *Tijk;
        double *R1, *R2, *T1, *T2;
/*      Length=atGetDouble(ElemData,"Length"); check_error();*/
        M66=atGetDoubleArray(ElemData,"M66"); check_error();
        Tijk=atGetDoubleArray(ElemData,"Tijk"); check_error();
        /*optional fields*/
        R1=atGetOptionalDoubleArray(ElemData,"R1"); check_error();
        R2=atGetOptionalDoubleArray(ElemData,"R2"); check_error();
        T1=atGetOptionalDoubleArray(ElemData,"T1"); check_error();
        T2=atGetOptionalDoubleArray(ElemData,"T2"); check_error();
        Elem = (struct elem*)atMalloc(sizeof(struct elem));
        Elem->Length=Length;
        Elem->M66=M66;
        Elem->Tijk=Tijk;
        /*optional fields*/
        Elem->R1=R1;
        Elem->R2=R2;
        Elem->T1=T1;
        Elem->T2=T2;
    }
    MatrixTijkPass(r_in, Elem->M66, Elem->Tijk, Elem->T1, Elem->T2, Elem->R1, Elem->R2, num_particles);
    return Elem;
}

MODULE_DEF(MatrixTijkPass)        /* Dummy module initialisation */
#endif /*defined(MATLAB_MEX_FILE) || defined(PYAT)*/

#ifdef MATLAB_MEX_FILE
void mexFunction(	int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs == 2) {
        double *r_in;
        const mxArray *ElemData = prhs[0];
        int num_particles = mxGetN(prhs[1]);
        double Length, *M66, *Tijk;
        double *R1, *R2, *T1, *T2;
/*      Length=atGetDouble(ElemData,"Length"); check_error();*/
        M66=atGetDoubleArray(ElemData,"M66"); check_error();
        Tijk=atGetDoubleArray(ElemData,"Tijk"); check_error();
        /*optional fields*/
        R1=atGetOptionalDoubleArray(ElemData,"R1"); check_error();
        R2=atGetOptionalDoubleArray(ElemData,"R2"); check_error();
        T1=atGetOptionalDoubleArray(ElemData,"T1"); check_error();
        T2=atGetOptionalDoubleArray(ElemData,"T2"); check_error(); 		
        /* ALLOCATE memory for the output array of the same size as the input  */
        plhs[0] = mxDuplicateArray(prhs[1]);
        r_in = mxGetDoubles(plhs[0]);
        MatrixTijkPass(r_in, M66, Tijk, T1, T2, R1, R2, num_particles);	
	}
    else if (nrhs == 0) {
        /* list of required fields */
	    plhs[0] = mxCreateCellMatrix(2,1);
	    mxSetCell(plhs[0],0,mxCreateString("M66"));
	    mxSetCell(plhs[0],1,mxCreateString("Tijk"));
	    if (nlhs>1) {
            /* list of optional fields */
            plhs[1] = mxCreateCellMatrix(4,1);
            mxSetCell(plhs[1],0,mxCreateString("T1"));
            mxSetCell(plhs[1],1,mxCreateString("T2"));
            mxSetCell(plhs[1],2,mxCreateString("R1"));
            mxSetCell(plhs[1],3,mxCreateString("R2"));
	    }
    }
    else {
        mexErrMsgIdAndTxt("AT:WrongArg","Needs 0 or 2 arguments");
    }
}
#endif
