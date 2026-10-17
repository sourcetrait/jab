j _start [9:44] :a worker on hart 1 asleep on word, woken until a wake answers it asleep, then word changed and the worker woken until it is done: `owners: woken asleep, then done` and exit 0, every step within WAIT_TICKS
j local refused [46:48] :the start refused: `owners: the start refused` and exit 3
j local never_slept [50:52] :no wake answered the worker asleep within WAIT_TICKS: `owners: the worker never slept` and exit 3
j local never_done [54:56] :the worker not done within WAIT_TICKS: `owners: the worker never finished` and exit 3
j local waiter word addr [58:64] :the worker: asleep in jab.sys.worker.wait while word holds 0, then done set and its exit
