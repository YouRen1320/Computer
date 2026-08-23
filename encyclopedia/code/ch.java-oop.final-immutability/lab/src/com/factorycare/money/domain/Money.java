package com.factorycare.money.domain;

public final class Money {
    private final long cents;
    private final String currency;

    public Money(long cents, String currency) {
        if (cents < 0) {
            throw new IllegalArgumentException("cents must not be negative");
        }
        if (currency == null || currency.isBlank()) {
            throw new IllegalArgumentException("currency must have text");
        }
        this.cents = cents;
        this.currency = currency;
    }

    public long cents() {
        return cents;
    }

    public String currency() {
        return currency;
    }

    public Money plus(Money other) {
        if (other == null) {
            throw new IllegalArgumentException("other must not be null");
        }
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("currency mismatch");
        }
        return new Money(Math.addExact(cents, other.cents), currency);
    }
}
