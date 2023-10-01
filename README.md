# validatorHotSwap
Modified version of Latitude.sh script for solana validator's hot swap.

The original script can be found here: https://latitudesh.manystake.com/node-transition-hot-swap

This version accepts an alias (nickname) for the server, previously set with the ssh script.
If there are problems on the primary validator, you can choose to shutdown directly 
by inserting the string "stop" as second parameter (e.g., prolonged state of delinquency)
or any other problem that is impeding voting operations.

example of use: ./node-transitionTo.sh dallas stop

Note: Primary validator is always the voting node

This version is constantly being modified
