# validatorHotSwap
Modified version of Latitude.sh script for solana validator's hot swap.

The original script can be founded here: https://latitudesh.manystake.com/node-transition-hot-swap

This version accept alias (nickname) for the server, previously set with the ssh script.
If problems on primary validator are presents, you can choose to shutdown directly,
by inserting the string "stop" as second parameter.
eg. prolonged state of delinquency or any other problem that is impeding voting operations  

example of use: ./node-transitionTo.sh dallas stop

Note: Primary validator is always the voting node

This version is constantly being modified
