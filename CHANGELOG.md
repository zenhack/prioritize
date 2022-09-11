# 0.4

- There is now a square-root urgency growth rate that is slower than
  linear.

# 0.3

- The "urgency growth rate" now has an effect a day sooner. Previously,
  since `x^2` and `x` are the same when x = 1, the ordering of tasks
  which are one day past due effectively did not take into account their
  urgency. We now shift things forward a day before doing the
  computation, so that quadratic is more urgent than linear out of
  the gate.

# 0.2.1

- Adjust the logic added in 0.2, such that it gracefully deals with
  network errors.

# 0.2

- Push updates to clients, so you don't need to refresh if you make
  a change on another device.

# 0.1.2

- Fix some bugs in time arithmetic that sometimes resulted in odd,
  non-deterministic behavior re: which jobs were counted as due.

# 0.1.1

- Fix a divide-by-zero error that sometimes caused the page to fail to
  respond.

# 0.1

- First release on the app market.
