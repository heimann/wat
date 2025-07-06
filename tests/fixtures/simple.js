const VERSION = "1.0.0";

class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }
    
    distance(other) {
        return Math.sqrt((this.x - other.x) ** 2 + (this.y - other.y) ** 2);
    }
}

function add(a, b) {
    return a + b;
}

const multiply = (a, b) => a * b;

function main() {
    console.log("Hello, World!");
}

class Status {
    static OK = 0;
    static ERROR = 1;
}

let globalConfig = {
    debug: false,
};

var oldStyle = true;

async function fetchData(url) {
    const response = await fetch(url);
    return response.json();
}