#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <time.h>

using namespace std;

int main(int argc, char* argv[]) {
    if (argc != 2) {
        cerr << "Usage: " << argv[0] << " <input_file>" << endl;
        return 1;
    }

    // Seed the random number generator
    srand(time(NULL));

    // Open the input file
    ifstream input(argv[1]);
    if (!input.is_open()) {
        cerr << "Error: Unable to open input file " << argv[1] << endl;
        return 1;
    }

    // Read the entire input file into a string
    string data((istreambuf_iterator<char>(input)), istreambuf_iterator<char>());

    // Close the input file
    input.close();

    // Mutate the string
    for (int i = 0; i < data.length(); i++) {
        // Randomly decide to modify this character
        if (rand() % 2 == 0) {
            // Generate a random character
            char c = (char)(rand() % 256);

            // Modify the character in the string
            data[i] = c;
        }
    }

    // Print the mutated string
    cout << data << endl;

    return 0;
}
