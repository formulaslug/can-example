// Copyright (c) 2016-2017 Formula Slug. All Rights Reserved.

#include <stdint.h>

#include <memory>

#include <IntervalTimer.h>

#include "Timer.h"
#include "fs-0-core/CANopen.h"
#include "fs-0-core/CANopenPDO.h"
#include "fs-0-core/InterruptMutex.h"
#include "fs-0-core/make_unique.h"

// timer interrupt handlers
void _1sISR();
void _20msISR();
void _3msISR();

// contains and controls all CAN related functions
static std::unique_ptr<CANopen> g_canBus;

int main() {
  Serial.begin(115200);

  constexpr uint32_t kID = 0x680;
  constexpr uint32_t kBaudRate = 250000;
  g_canBus = std::make_unique<CANopen>(kID, kBaudRate);

  IntervalTimer _1sInterrupt;
  _1sInterrupt.begin(_1sISR, 1000000);

  IntervalTimer _20msInterrupt;
  _20msInterrupt.begin(_20msISR, 20000);

  IntervalTimer _3msInterrupt;
  _3msInterrupt.begin(_3msISR, 3000);

  InterruptMutex interruptMut;

  Timer softTimer(250);

  while (1) {
    if (softTimer.isExpired()) {
      std::lock_guard<InterruptMutex> lock(interruptMut);

      // print all transmitted messages
      g_canBus->printTxAll();

      // print all received messages
      g_canBus->printRxAll();
    }

    softTimer.update();
  }
}

/**
 * @desc Performs period tasks every second
 */
void _1sISR() {
  // enqueue heartbeat message to g_canTxQueue
  const HeartbeatMessage heartbeatMessage(kCobid_node3Heartbeat);
  g_canBus->queueTxMessage(heartbeatMessage);
}

/**
 * @desc Processes and transmits all messages in g_canTxQueue
 */
void _20msISR() { g_canBus->processTxMessages(); }

/**
 * @desc Processes all received CAN messages into g_canRxQueue
 */
void _3msISR() { g_canBus->processRxMessages(); }
