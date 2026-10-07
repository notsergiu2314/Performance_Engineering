#include <iostream>
#include <vector>
#include <time.h>
#include <limits>
#include <iomanip>
// for output to .csv, plotting in separate python script
#include <fstream> 

// matrix-vector multiplication 
vector<double> vec_mat_mul(const vector<double>& A, const vector<double>& B, int n)
{
    vector<double> C(n * n, 0.0);

    for (int i = 0; i < n; ++i) {
        for (int k = 0; k < n; ++k) {
            double aik = A[i * n + k];
            for (int j = 0; j < n; ++j) {
                C[i * n + j] += aik * B[k * n + j];
            }
        }
    }

    return C;
}