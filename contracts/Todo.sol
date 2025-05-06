// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

contract Todo {
    struct Task {
        string task;
        bool completed;
    }

    Task[] public tasks;
}