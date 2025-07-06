// Java test fixture
package com.example;

import java.util.List;
import java.util.ArrayList;

public class Point {
    private double x;
    private double y;
    
    public static final String VERSION = "1.0.0";
    
    public Point(double x, double y) {
        this.x = x;
        this.y = y;
    }
    
    public double getX() {
        return x;
    }
    
    public double distance(Point other) {
        double dx = this.x - other.x;
        double dy = this.y - other.y;
        return Math.sqrt(dx * dx + dy * dy);
    }
}

interface Drawable {
    void draw();
}

class Shape implements Drawable {
    protected String name;
    
    public Shape(String name) {
        this.name = name;
    }
    
    @Override
    public void draw() {
        System.out.println("Drawing " + name);
    }
}

enum Status {
    OK,
    ERROR
}

public class Main {
    private static int counter = 0;
    
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
    
    private static int add(int a, int b) {
        return a + b;
    }
}