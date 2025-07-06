// C test fixture
#include <stdio.h>
#include <stdlib.h>

#define VERSION "1.0.0"
#define MAX_SIZE 100

typedef struct {
    double x;
    double y;
} Point;

typedef enum {
    STATUS_OK,
    STATUS_ERROR
} Status;

// Global variable
int global_counter = 0;
static const char* PROGRAM_NAME = "test";

// Function declarations
int add(int a, int b);
static void print_point(const Point* p);

// Function definitions
int add(int a, int b) {
    return a + b;
}

static void print_point(const Point* p) {
    printf("Point(%f, %f)\n", p->x, p->y);
}

double distance(Point* p1, Point* p2) {
    double dx = p1->x - p2->x;
    double dy = p1->y - p2->y;
    return sqrt(dx * dx + dy * dy);
}

// Union type
union Data {
    int i;
    float f;
    char str[20];
};

// Main function
int main(int argc, char* argv[]) {
    printf("Hello, C!\n");
    return 0;
}

// Typedef for function pointer
typedef int (*operation)(int, int);

// Struct with function pointer
struct Calculator {
    operation op;
    int last_result;
};