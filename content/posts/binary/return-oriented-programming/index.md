---
title: "Part 1: Intro to fiddling with binaries"
subtitle: "Deep in the trenches of 0s and 1s"
date: 2025-04-28
description: "This is a start of a series where we will go learn binary exploitation. We will start with explaining some basics to get everyone up to speed."
tags: ["Binary", "exploitation", "assembly", "stack", "memory"]
categories: ["Binary Exploitation"]
authors: ["Sam"]
series: ["Busting the stack"]
draft: false
---
<!--more-->

Welcome home. In this series, we will go on a tour in the realm of binary exploitation. We will start with the basics and some
essential concepts for this to be a success for everyone. If you are already familiar with what you see in the table of contents,
jump to the next post (*hopefully I wrote it already :D*).

## The plan

We will explain what is necessary only for now. We will dive deeper when we need to later.
Take it easy and don't worry too much if some things are not clear yet. It will all make sense eventually.
I highly recommend trying and following along if you can. I will try to provide some code snippets and examples to help you out.

## The memory layout

So, when we run a binary, a couple of things happen behind the scenes.
This binary has a format when it is on disk. All we need to know for now that it is structured in some type of way.
When we run the said binary, the operating system takes this structure from the disk and loads it into memory.
When it loads it into memory, it organizes it in a different structure. This structure is the same for all binaries within the same operating system.
In this section, we will look at the memory layout of a binary when it is already loaded into memory.

Memory here by the way, is main memory. Also known as RAM. This is the memory that is used to run programs.

![The memory layout of a binary](./mem_layout.jpg)

[Layout straight out of Wikipedia](https://en.wikipedia.org/wiki/Data_segment)

So this layout, is the same for every binary. Every binary has its own isolated memory layout. Every binary thinks its
the only thing running on the operating system. This is called *process isolation*.
Note that a process here means a program that is now living in memory.

- Binary -> A file that describes a program. This file is on disk and is not running.
- Process -> A program that is now loaded into memory and is running or about to run.

There is of course a little more to it but we don't need to worry about none of that.

Let's go through this image step by step from the bottom to the top.

- text segment: also known as the code segment. This is where the *code* of the binary is stored.
It is a read-only part of memory. The CPU uses this part to know what to do to get this binary going.
- data segment: This is where your *initialized* global variables, static variables, constants and such. Initialized here means it starts with a value.
An example:

```C
static int a = 5;
```

- BSS segment: Same as above but the variables here are the ones that are *not initialized*. They don't start with a value.

```C
static int a;
```

- heap segment: This place is used for *dynamic memory allocation*. In other words, this is where memory space gets reserved for variables that are created at runtime (read during execution). In C, this is done with functions like `malloc`, `calloc`, `realloc` and the memory gets released with `free`. Something to note about the heap is that it grows upwards. This means that when we allocate memory, it will grow towards the higher addresses in memory. You don't need to worry too much about this right now.

```C
int *a = malloc(sizeof(int) * 10);
// This piece above will store 10 integers in the heap. It will give us a pointer to the first one.
// We will come around to pointers when we need to.
```

- stack segment: The main dish for our topic. This segment store all kinds of things. It is used for function local variables, function arguments, return addresses and such.
It represent a *state* of the running process. It helps the CPU keep track of what is going on right now and where things are. In other words, it helps the CPU keep track of the execution *context*.

```C
void hello(int arg1, int arg2){
  int a = 5;
  // etc ...
  return;
}
// arg1, arg2, a and a couple of other values are kept in the stack in something
// called a *stack frame*. More on that in the next section.
```

## The stack

Let's zoom in onto this stack segment we just mentioned. This is going to be the stage of many of our attacks.

## Some Assembly
