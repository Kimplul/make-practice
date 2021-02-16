#include <iostream>
extern "C" {
        #include "../code1/code1.h"
}

int main(){
        std::cout << "hawwo?" << std::endl;
        use_one();
        return 0;
}
