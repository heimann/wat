#!/usr/bin/env python3

VERSION = "1.0.0"

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    
    def distance(self, other):
        return ((self.x - other.x)**2 + (self.y - other.y)**2)**0.5

def add(a, b):
    return a + b

def main():
    print("Hello, World!")

class Status:
    OK = 0
    ERROR = 1

global_config = {
    "debug": False,
}

async def fetch_data(url):
    pass