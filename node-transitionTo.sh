#!/bin/bash

# Modified version of Latitude.sh script for hot swap.
# This version accept alias (nickname) for the server, previously set with the ssh script.
# If problems on primary validator are presents, you can choose to shutdown directly,
# by inserting the string "stop" as second parameter.
# eg. prolonged state of delinquency or any other problem that is impeding voting operations  

# example of use: ./node-transitionTo.sh dallas stop

# Note: Primary validator is always the voting node

if test -z "$1"
then
      echo "Error: Missing target alias ( eg. dallas or nyc )"
      exit 1
fi

# Define here the IP of the node to transition voting operation
ALIAS_NODE=$1
TRANSITIONAL_NODE_IP=$1
TRANSITIONAL_NODE_LEDGER_DIR=/mnt/solana_ledger/ledger
TRANSITIONAL_NODE_SOLANA_USER=solana
TRANSITIONAL_NODE_SOLANA_USER_HOME_DIR=/home/solana
TRANSITIONAL_NODE_SECRET_DIR=/home/solana/.secrets
TRANSITIONAL_NODE_TSH_DIR=/home/solana/tsh
TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE=$TRANSITIONAL_NODE_SECRET_DIR/funded-validator-keypair.json
TRANSITIONAL_NODE_UNFUNDED_VALIDATOR_KEYPAIR_FILE=$TRANSITIONAL_NODE_SECRET_DIR/unfunded-validator-keypair.json
TRANSITIONAL_NODE_SOLANA_PATH=/home/solana/.local/share/solana/install/active_release/bin

main_function()
{

# Validate that TRANSITIONAL_NODE_IP is defined
#[[ -z "$TRANSITIONAL_NODE_IP" ]] && { echo "TRANSITIONAL_NODE_IP undefined. please edit the script before using it"; exit 1; }

# Validate that ssh connectivity is correctly setup before running transition operation
#ssh -q -o BatchMode=yes  -o StrictHostKeyChecking=no -o ConnectTimeout=5 #$TRANSITIONAL_NODE_SOLANA_USER@$TRANSITIONAL_NODE_IP 'exit 0'
#[ $? != 0 ] && { echo "SSH connection to $server over port 22 is not possible"; exit 1; }

# Validate that ssh connectivity is correctly setup before running transition operation
ssh -o ConnectTimeout=5 $ALIAS_NODE 'exit 0'
[ $? != 0 ] && { echo "SSH connection to $server over port 22 is not possible"; exit 1; }

# Check if TRANSITIONAL_NODE_LEDGER_DIR exists
ssh $ALIAS_NODE "ls $TRANSITIONAL_NODE_LEDGER_DIR" > /dev/null 2>&1
[ $? != 0 ] && { echo "$TRANSITIONAL_NODE_LEDGER_DIR doesn't exists in TRANSITIONAL_NODE"; exit 1; }

# Check if TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE exists
ssh $ALIAS_NODE "ls $TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE" > /dev/null 2>&1
[ $? != 0 ] && { echo "$TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE doesn't exists in TRANSITIONAL_NODE"; exit 1; }

# Check if SOLANA CLI is installed exists
ssh $ALIAS_NODE "$TRANSITIONAL_NODE_SOLANA_PATH/solana --version" > /dev/null 2>&1
[ $? != 0 ] && { echo "SOLANA CLI not found in TRANSITIONAL_NODE check the TRANSITIONAL_NODE_SOLANA_PATH VAR"; exit 1; }

# Check if unfunded validator keypair exists in this machine
[ ! -f /home/solana/.secrets/unfunded-validator-keypair.json ] && { echo "Unfunded validator keypair doesn't exists on this machine"; exit 1; }

# Check if tower file exists
[ ! -f /mnt/solana_ledger/ledger/tower-1_9-"$(solana-keygen pubkey /home/solana/.secrets/validator-keypair.json)".bin ] && { echo "There is no tower file /mnt/solana/ledger/tower-1_9-$(solana-keygen pubkey /home/solana/.secrets/validator-keypair.json).bin either the machine is running with the unfunded-validator-keypair in non voting mode or your ledger dir is wrong!!!"; exit 1; }

# Check unfunded-validator-keypair should be different on each nodes
TRANSITIONAL_NODE_UNFUNDED_VALIDATOR_KEYPAIR_FILE_SHA1SUM=$(ssh $ALIAS_NODE "cat $TRANSITIONAL_NODE_UNFUNDED_VALIDATOR_KEYPAIR_FILE | sha1sum")
[ "$TRANSITIONAL_NODE_UNFUNDED_VALIDATOR_KEYPAIR_FILE_SHA1SUM" == "$(cat /home/solana/.secrets/unfunded-validator-keypair.json | sha1sum)"  ] && { echo "Unfunded validator keypair must be different on each nodes"; exit 1; }

# Check funded-validator-keypair should be the same on each nodes
TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE_SHA1SUM=$(ssh $ALIAS_NODE "cat $TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE | sha1sum")
[ "$TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE_SHA1SUM" != "$(cat /home/solana/.secrets/funded-validator-keypair.json | sha1sum)"  ] && { echo "Funded validator keypair must be the same on each nodes"; exit 1; }


if [ "$2" == "stop" ]; then
  echo -e
  read -p "WARNING: Confirm that a serious problem is present on the primary validator and that you want to stop? (y/n)? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
  	#[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
  	exit 1
  else
	#Shutdown of the primary validator due to some problems
	echo "Shutdown of the primary validator due to some problems"
	sudo systemctl stop solana-validator.service
	sleep 1s
  fi
else
  # Wait for a restart window
  solana-validator -l /mnt/solana_ledger/ledger wait-for-restart-window --min-idle-time 2 --skip-new-snapshot-check

  # Stop voting operation on the currently voting node
  echo "Stop voting operation on the currently voting node"
  solana-validator -l /mnt/solana_ledger/ledger set-identity /home/solana/.secrets/unfunded-validator-keypair.json
  sleep 1s
fi

echo -e
echo "Primary Validator stopped. Migrating..."

# Move symlink to unfunded validator keypair to prevent this node to vote concurrently in case of service restart
ln -sf /home/solana/.secrets/unfunded-validator-keypair.json /home/solana/.secrets/validator-keypair.json

# Copy the tower file to the node take over voting operation
scp /mnt/solana_ledger/ledger/tower-1_9-"$(solana-keygen pubkey /home/solana/.secrets/funded-validator-keypair.json)".bin $ALIAS_NODE:$TRANSITIONAL_NODE_LEDGER_DIR

# Start voting operation in the transitioned node
ssh $ALIAS_NODE "$TRANSITIONAL_NODE_SOLANA_PATH/solana-validator -l $TRANSITIONAL_NODE_LEDGER_DIR set-identity --require-tower $TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE"

# Move symlink to funded validator keypair to permit vote operation in case of service restart
ssh $ALIAS_NODE "ln -sf $TRANSITIONAL_NODE_FUNDED_VALIDATOR_KEYPAIR_FILE $TRANSITIONAL_NODE_SECRET_DIR/validator-keypair.json"

# Stop of TSH (Telegram Shell) service on the currently voting node
echo "Stop of TSH (Telegram Shell) service on the currently voting node"
sudo systemctl stop tsh.service
sleep 1s

# Copy the TSH (Telegram Shell) files to the node take over voting operation
scp /home/solana/tsh/config.db $ALIAS_NODE:$TRANSITIONAL_NODE_TSH_DIR
scp /home/solana/tsh/service.log $ALIAS_NODE:$TRANSITIONAL_NODE_TSH_DIR

# Start TSH (Telegram Shell) service in the transitioned node
echo "Start TSH (Telegram Shell) service in the transitioned node"
ssh -t $ALIAS_NODE "sudo systemctl restart tsh.service"
}

#----------

echo "Hot Swap Transition to $ALIAS_NODE" > /home/solana/tsh/transition.log
date >> /home/solana/tsh/transition.log

if [ -z $TERM ]; then
  # if not run via terminal, redirecting
  main_function 2>&1 >> /home/solana/tsh/transition.log
else
  # run via terminal, only output to screen
  main_function 2>&1 >> /home/solana/tsh/transition.log
fi

# Copy the transition.log file of this session to the node take over voting operation
scp /home/solana/tsh/transition.log $ALIAS_NODE:$TRANSITIONAL_NODE_TSH_DIR