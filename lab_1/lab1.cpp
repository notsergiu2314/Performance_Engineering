#include <iostream>
#include <chrono>
#include <vector>
using namespace std;

vector<double> multiply_matrices(const vector<double>& A, const vector<double>& B, int n) {
    vector<double> C(n*n, 0.0);
    for (int i = 0; i < n; ++i) {
        for (int k = 0; k < n; ++k) {
            double aik = A[i*n + k];
            for (int j = 0; j < n; ++j) {
                C[i*n + j] += aik * B[k*n + j];
            }
        }
    }
    return C;
}

int main() {

    auto start_time = chrono::high_resolution_clock::now();
    
    int n = 512; // matrix size (change as needed)

    // allocate matrices in row-major 1D vectors
    vector<double> A(n*n), B(n*n), C(n*n, 0.0);

    // initialize A and B with some values
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < n; ++j) {
            A[i*n + j] = (double)(i + j);
            B[i*n + j] = (double)(i - j);
        }
    }

    C = multiply_matrices(A, B, n);

    auto end_time = chrono::high_resolution_clock::now();
    chrono::duration<double> elapsed = end_time - start_time;
    cout << "Elapsed time: " << elapsed.count() << " seconds\n";

    // print a checksum to avoid optimizing away the computation
    double checksum = 0.0;
    for (double v : C) checksum += v;
    cout << "Checksum: " << checksum << "\n";
    
   
    return 0;
}
