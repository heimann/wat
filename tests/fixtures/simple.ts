// TypeScript test fixture
const VERSION = "1.0.0";

interface Point {
    x: number;
    y: number;
}

type Status = "ok" | "error";

enum Color {
    Red = 0,
    Green = 1,
    Blue = 2,
}

class Shape {
    constructor(public name: string) {}
    
    area(): number {
        return 0;
    }
}

function add(a: number, b: number): number {
    return a + b;
}

const multiply = (a: number, b: number): number => a * b;

export function main() {
    console.log("Hello, TypeScript!");
}

namespace Utils {
    export function format(str: string): string {
        return str.trim();
    }
}

type ComplexType<T> = {
    data: T;
    timestamp: Date;
};

let globalConfig: { debug: boolean } = {
    debug: false,
};

export default class DefaultExport {
    static readonly VERSION = "1.0.0";
}