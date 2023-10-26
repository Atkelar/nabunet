/*

A simple status LED blinker that can be triggered from a queue and the main loop.

*/

#ifndef BLINKYSTATH
#define BLINKYSTATH

struct BlinkEntry
{
    bool isStatus;
    int ledPin;
    int count;
    int repeat;
    BlinkEntry *next;
};

class BlinkyStat
{
  public:
    BlinkyStat(int delay);

    // repeat <= 0 -> infinite
    void Queue(int ledPin, int count, int repeat = 1);
    // queues and waits...
    void Signal(int ledPin, int count);

    void Status(int ledPin, int timeout);

    void TickNow();
  private:
    BlinkEntry *head, *tail;
    BlinkEntry counter;
    int blinkDelay;
    unsigned long lastRelevantTick;
    bool isOn, isCounting, hasItem;
};


extern BlinkyStat Blinky;

#endif