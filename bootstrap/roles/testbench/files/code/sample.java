package com.example;

import java.util.List;

/** Javadoc comment. */
public class Service<T> {
    private static final int MAX = 10;
    private final List<T> items;

    public Service(List<T> items) {
        this.items = items;
    }

    @Override
    public boolean isEmpty() {
        // TODO: builtins, operators
        return items.size() == 0 && MAX > 0;
    }
}
