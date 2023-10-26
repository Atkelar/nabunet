
#include "BlinkyStat.h"
#include "Definitions.h"

BlinkyStat Blinky(BLINK_DELAY);

BlinkyStat::BlinkyStat(int delay)
{
    head = tail = NULL;
    lastRelevantTick = 0;
    hasItem = false;
    blinkDelay = delay;
}

void BlinkyStat::Queue(int ledPin, int count, int repeat = 1)
{
    BlinkEntry* n = new BlinkEntry();
    n->ledPin = ledPin;
    n->count = count;
    n->repeat = repeat;
    n->next = NULL;
    if (tail == NULL)
    {
        head = tail = n;
    }
    else
    {
        tail->next = n;
        tail = n;
    }
}


void BlinkyStat::Signal(int ledPin, int count)
{
    Queue(ledPin, count);
    while (head != NULL || hasItem)
    {
        delay(1);
        TickNow();
    }
}

void BlinkyStat::TickNow()
{
    unsigned long now = millis();
    if (!hasItem && head != NULL)
    {
        BlinkEntry *current = head;
        head = head->next;
        if (head == NULL)
            tail = NULL;
        current->next = NULL;
        lastRelevantTick = 0;
        isOn = false;
        isCounting = true;
        counter.count = current->count;
        counter.ledPin = current->ledPin;
        counter.repeat = current->repeat;
        delete current;
        hasItem = true;
    }

    if (hasItem)
    {
        unsigned long delta = now - lastRelevantTick;
        if (isCounting)
        {
            if (delta > blinkDelay)
            {
                lastRelevantTick = now;
                isOn = !isOn;
                digitalWrite(counter.ledPin, isOn ? LED_ON : LED_OFF);
                if (!isOn)
                {
                    counter.count--;
                    if (counter.count <= 0)
                    {
                        isCounting = false;
                    }
                }
            }
        }
        else
        {
            if (delta > blinkDelay * 2)
            {
                // we are done; delay after blink is over, check for reapeat...
                if (counter.repeat > 0)
                {
                    counter.repeat--;
                    if (counter.repeat > 0)
                    {
                        Queue(counter.ledPin, counter.count, counter.repeat);
                    }
                }
                else
                {
                    Queue(counter.ledPin, counter.count, 0);
                }
                hasItem = false;
            }
        }
    }
}