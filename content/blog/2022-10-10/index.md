---
title: "Debugging on embedded devices"
type: "blog"
date: "2022-10-10"
---

This post provides an non-exhaustive overview of the techniques that can be used to debug embedded devices.

<!--more-->

Debugging embedded devices can pose some interesting challenges:

- Logging comes with a significant performance penalty
  - bug might disappear when logging is enabled

- Interrupting the whole CPU isn't always possible
  - might have peripherals (e.g. TIMERS) generating interrupts
  - code will have expectations about this, will crash on resume

- Bug can come from hardware
  - Logic might be embedded in peripherals (e.g. PPI, SHORTS)
  - Faulty peripheral can break code assumptions

These challenges might not be exclusive to embedded development, but are a common occurrence here.
This blog post describes some of the techniques that can be used to work around some of those problems.

It is mostly written for an embedded developer using the Zephyr RTOS on Nordic Semi nRF52/3 platforms.

Table of contents
-----------------

{{< table_of_contents >}}

## ARM debug IP

ARM SoCs usually have these hardware blocks to help with debugging:

ITM: Instrumentation Trace Macrocell
- logs events from DWT (Debug Watch Unit): exceptions, data watchpoints
- SWIT events: user-provided event data
- usually outputs over SWO
  - supported by most probes
  - can also connect UART-USB converters

ETM: Embedded Trace Macrocell
- logs every single executed instruction
- usually outputs over high-speed trace port
- requires expensive debug probe
- very useful for profiling code

ETB: Embedded Trace Buffer
- buffers the ETM data
- allows having a slower trace port clock rate
- isn't magic, only helps for short bursts of processing

## Debugger

A debugger is a piece of software that is able to control the instruction flow (pause the CPU, execute arbitrary code, etc), inspect and modify the device's running memory.

On embedded devices, this is typically done through an "In-circuit Emulator", serving as the interface between the computer running the debugger and the embedded CPU/SoC. All nRF development kits include an on-board ICE from Segger (J-Link).

Pros:
- Visualize data structures easily
- Redirect control flow
- Disassemble a function
- User-friendly interfaces
- Doesn't need expensive hardware

Cons:
- Can't restart execution after pausing due to real-time constraints on some systems
- Can slow down the program, making a bug unreproducible
- Increases SoC power consumption (debug IP has to be on)

For the nordic SoCs, we can use a variety of debuggers, the most common being Segger's Ozone and GNU GDB.
As segger Ozone is pretty discoverable, we will rather focus on basic GDB usage.

As Ozone is made by Segger, they connect directly to the debug probe (J-Link). Connecting GDB to the target involves spawning a GDB Server which will communicate with the probe, and GDB itself, which will communicate with the server.

### Launching a GDB session

It is as easy as running `west debug` if running a standard zephyr project.

#### nRF52840 project.
- running on a nRF52840 DK
- with segger ID 683578642
- assuming application ELF is `./zephyr.elf`

1. Start the GDB server
`JLinkGDBServer -device nRF52840_xxAA -if SWD -LocalhostOnly 1 -nologtofile -nogui -nohalt -noreset -select usb=683578642`
2. Start GDB
`arm-none-eabi-gdb ./zephyr.elf`
3. Connect to the server (from inside the gdb process)
`target remote localhost:2331`

#### nRF5340 project.
- running on a nRF5340 DK
- with segger ID 960154771
- assuming application ELF is `./zephyr.elf`
- we want to connect to the network core

1. Start the GDB server
`JLinkGDBServer -device nRF5340_xxAA_NET -if SWD -LocalhostOnly 1 -nologtofile -nogui -nohalt -noreset -select usb=960154771`
2. Follow steps 2 and 3 of nRF52

### GDB usage

What we usually want to do is:
- set code breakpoints
- set data watchpoints (stop when a variable changes)
- see and manipulate the call stack when we are stopped
- step through the code
- inspect some data structures

All commands listed here should be run in a GDB command prompt/session.
Most commands have built-in help: e.g. `help list` to show the help for the `list` command.

#### Reset the target

`monitor reset`

#### Run the program

- `continue` after a `monitor reset`.
- `run` if not debugging a HW target.

#### Breakpoints

##### Add a breakpoint

There are multiple ways of adding breakpoints:
- line in the current file: `break 100`
- line in a different file: `break l2cap.c:100`
- function: `break l2cap_check_security`
- function in file: `break bt.c:cmd_init`
- memory address: `b *(0x00022244)`

##### List breakpoints

Will also list watchpoints

`info break`

##### Delete a breakpoint

Get the breakpoint ID from `info break`, e.g., 5 then use it: `delete 5`

#### Watchpoints

Say we want to watch a variable named 'ctx_shell':
`watch ctx_shell`

#### Call stack

Call `backtrace` or `bt`.
Get something like this:

``` shell
##0  0x00022244 in cmd_init (sh=0x50ad0 <shell_uart>, argc=1, argv=0x20009168 <shell_uart_stack+1704>)
    at /home/john/repos/zephyrproject/zephyr/subsys/bluetooth/shell/bt.c:706
##1  0x00009c30 in exec_cmd (help_entry=0x20009150 <shell_uart_stack+1680>, argv=0x20009168 <shell_uart_stack+1704>,
    argc=<optimized out>, shell=0x50ad0 <shell_uart>) at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:558
##2  execute (shell=shell@entry=0x50ad0 <shell_uart>) at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:800
##3  0x00009e4e in state_collect (shell=0x50ad0 <shell_uart>) at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:1002
##4  shell_process (shell=0x50ad0 <shell_uart>) at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:1470
##5  0x000486b0 in shell_signal_handle (shell=shell@entry=0x50ad0 <shell_uart>, sig_idx=sig_idx@entry=SHELL_SIGNAL_RXRDY,
    handler=handler@entry=0x9c75 <shell_process>) at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:1289
##6  0x0000a63a in shell_thread (arg_log_backend=<optimized out>, arg_log_level=<optimized out>, shell_handle=0x50ad0 <shell_uart>)
    at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:1346
##7  shell_thread (shell_handle=0x50ad0 <shell_uart>, arg_log_backend=<optimized out>, arg_log_level=<optimized out>)
    at /home/john/repos/zephyrproject/zephyr/subsys/shell/shell.c:1305
##8  0x00047bd0 in z_thread_entry (entry=0xa5a9 <shell_thread>, p1=<optimized out>, p2=<optimized out>, p3=<optimized out>)
    at /home/john/repos/zephyrproject/zephyr/lib/os/thread_entry.c:36
##9  0xaaaaaaaa in ?? ()
Backtrace stopped: previous frame identical to this frame (corrupt stack?)
```

- Move up or down n frames (e.g. 3): `up 3` and `down 3`.
- Move to a specific frame (e.g. #4): `frame 4`
- Show which frame we're in: `frame`

#### Code listing

- view the code around the current lines: `list`
  - also works with functions: `list cmd_init`
- enable the built-in TUI: `tui enable`
- view assembly: `disassemble`
  - also works for functions: `disassemble cmd_init`

#### Control flow

- step a line (also steps into function calls): `step`
- step over a line (doesn't step into fn calls): `next`
- continue (until next break/watchpoint): `continue`
- finish executing current function and stop: `fin`
- get out of a loop: `until`
- execute N iterations of current loop: `until N`
- return from current function: `return`

#### Data

##### Print

`print` can be aliased to `p`.

- local variables: `info locals`
- function parameters: `info args`
- variable as hex: `p/x myvar`
- variable as ascii: `p /c myvar`
- array of 20 bytes: `p myarray[0]@20`
- value at address: `x 0x20009150`
- value at address interpreted as string: `x/s 0x20009150`
- print variable on every step: `display myvar`, `undisplay myvar`

Pretty-print a structure:
- `set print pretty`
- `print mystruct`
- `print *ptr_to_mystruct`
- `print mystruct.other_nested_struct`

##### Set

- set variable to value: `set myvar = 3`
- set variable to value of other variable: `set myvar = myothervar`

### Code breakpoints

Sometimes we need to define a breakpoint in code for various reasons.
It is possible to define a conditional breakpoint in GDB itself, but it will considerably slow down the program as there will be a communication for each step to check the breakpoint condition on the host (PC).

On ARM, with GCC, this will trigger a breakpoint: `__BKPT(1);`
The argument is the breakpoint number.
Then the condition can be defined using C code, which might be more flexible and faster than GDB.

On native builds (ie, x86/host), we can use this to cause a segfault (and stop the debugger) on all OSes:
`*(int*)0 = 0;`

### Debugging a bus fault

On ARM systems, a bus fault is when an illegal memory operation is performed.
This usually happens when trying to de-reference a null pointer, or trying to jump to a bad address (e.g. outside of the flash).
There are precise and imprecise bus faults: precise meaning that the fault correctly reports the offending instruction.
Imprecise means that the instruction reported might not be the correct one, disabling any instruction caches re-trying might prove useful.

Roughly goes like this:
1. get faulting instruction address from fault handler
2. find where in the code that instruction is:
  - using `disassemble` in GDB
  - using addr2line: `arm-none-eabi-addr2line -e zephyr.elf 0x00009c30`
  - searching through the assembly listing: `grep -C 10 "9c30:" zephyr.elf`
3. try to add a breakpoint (most likely in code) to catch the error before the fault happens
4. use GDB to play detective as usual

## Logging

"printf go brrrrr"

Sometimes, it is easier to log useful program state than fire up a heavy debugger.
Concurrency bugs / race conditions are a kind of bug where the debugger will almost be useless.

In that case, it is good to apply a mix of:
- extracting program state, through logging
- extracting context changes, through logging or using an efficient event tracing tool, like SystemView or even 'dumb' GPIO toggling in the most extreme cases.

### UART

This is the standard logging channel in almost all embedded applications.
Sometimes, only increasing the speed of the interface or the buffer sizes is enough to not slow down the system.

In zephyr, this is done by adjusting `CONFIG_LOG_BUFFER_SIZE`, and applying a device tree overlay to increase the speed.

### Segger RTT

This is a proprietary communication channel, that can be pretty fast.
It is composed of a C library, a J-Link debug probe and a PC program to view the log text.

In a nutshell, the MCU writes its data to a ring buffer in RAM, which is then read by the debug probe over SWD and relayed to the PC over USB. Segger says that with the latest probes, the CPU isn't even stopped when reading out the buffer.

There is a logging backend in zephyr for it. One can disable UART logging and enable RTT with this configuration:

``` conf
## Enable logging (and redirect printk to log output)
CONFIG_LOG=y
CONFIG_LOG_PRINTK=y
CONFIG_LOG_MODE_IMMEDIATE=y

## Free up UART
CONFIG_SERIAL=y
CONFIG_UART_CONSOLE=n
CONFIG_LOG_BACKEND_UART=n

## Enable logging on RTT
CONFIG_LOG_BACKEND_RTT=y
CONFIG_USE_SEGGER_RTT=y
CONFIG_SEGGER_RTT_BUFFER_SIZE_UP=8192
## Always get the latest logs, even if not read yet
CONFIG_LOG_BACKEND_RTT_MODE_OVERWRITE=y
```

### Logging to RAM

The fastest backend, just have a big enough ring buffer in RAM where logs are appended.
Not suitable for long-running sessions or small SoCs, but useful in the case of a system crash:
Just halt the device and dump the RAM contents through the debugger (e.g. GDB or nrfjprog/JLink).

### ARM ITM

The ARM ITM can be configured to emit custom events over standard SWO (Single Wire Output).
It can be thought of as a faster UART, especially since output data can be read by a standard UART transceiver.

Zephyr has a logging backend for it, see `CONFIG_LOG_BACKEND_SWO` to enable it, and `zephyr/subsys/logging/log_backend_swo.c` for an example implementation.

Additional resources:
https://blog.japaric.io/itm/
https://percepio.com/2016/06/09/arm-itm/

### SPI

SPI is a very simple protocol, basically a shift register emptying its contents on a wire.
Due to this, the IP in most SoCs can reach pretty high speeds, e.g. 32Mbps on nRF5340.
Coupled with DMA (Direct Memory Access), it makes for an ideal low-overhead logging channel.

One can then use a SPI-USB converter (e.g. FTDI chips/cables) or a logic analyzer to decode the data to ASCII.

#### Send a buffer (nRF52840)

Here is how to send the contents of a buffer using the SPIM peripheral on an nRF52840 SoC.
This particular piece of code (ran in the zephy blinky sample) has a processing time of ~30us between transfers.

``` c
##define INST NRF_SPIM3

void spi_test(void)
{
  printk("send over SPI\n");

  INST->PSEL.SCK =   3UL; /* P1.10 */
  INST->PSEL.MOSI =  4UL; /* P1.11 */
  INST->PSEL.MISO =  0x80000000; /* not connected */
  INST->PSEL.CSN =   0x80000000; /* not connected */

  INST->FREQUENCY = SPIM_FREQUENCY_FREQUENCY_M8; /* 4 MHz */
  INST->CONFIG = 0;

  INST->ENABLE = 7UL;
  INST->TASKS_STOP = 1;
  INST->RXD.MAXCNT = 0;

  /* The peripheral will _not_ copy the data, but read from this address
   * hence, it needs to stay valid for the duration of the transfer.
   */
  static char myarray[100];

  for(int i=0; i<10; i++) {
    int bytes = sprintf(myarray, "hello spi logger! i = %d\n", i);

    INST->TXD.MAXCNT = (uint32_t)bytes & 0xFFFF;
    INST->TXD.PTR = (uint32_t)myarray;

    INST->TASKS_START = 1;
    INST->EVENTS_END = 0;

    while(INST->EVENTS_END != 1) {
      __NOP();
    }
    INST->EVENTS_END = 0;
  }
  printk("send ok\n");
}
```

#### Using an FTDI cable

The [pyftdi library](https://eblot.github.io/pyftdi/) can be used to build a rudimentary log viewer/processor.

## GPIO tracing

In critical code sections (e.g. ISRs with hard deadlines, like radio packet interrupts), formatting and logging messages can be too much overhead and either break or change the behavior.

In those cases, we can still output some data, either through an efficient tracing tool (discussed later), or the poor person's tool which is just setting levels on GPIO pins and visualizing them with a logic analyzer.

That can be pretty useful for some basic code profiling and execution context logging (e.g. thread/isr changes).

### Code

#### Set a pin value

```c
##define MYPIN 10

/* Configure pin 0.10 as output */
NRF_P0->DIRSET = (1 << MYPIN);

/* Set pin to LOW */
NRF_P0->OUTCLR = (1 << MYPIN);
NRF_P0->OUT &= ~(1 << MYPIN); /* other method */

/* Set pin to HIGH */
NRF_P0->OUTSET = (1 << MYPIN);
NRF_P0->OUT |= (1 << MYPIN); /* other method */

/* Toggle pin */
NRF_P0->OUT ^= (1 << MYPIN);
```

#### Read a pin value

```c
##define MYPIN 10

/* Configure pin 0.10 as input */
NRF_P0->DIRCLR = (1 << MYPIN);

/* Read value */
bool value = NRF_P0->IN & (1 << MYPIN);
```

### Peripherals

On nRF SoCs, we have a powerful peripheral-to-peripheral interconnect system: PPI.
Through it, we can log processing events (by setting GPIO values in code) along hardware/peripheral events.
That is one, if not _the_ advantage of the GPIO method over the fancy tracing tools.

#### Set a pin when RADIO is sending a packet

We want to trace the duration of a radio packet using a logic analyzer.
To achieve this, we will set pin 0.10 between EVENTS_ADDRESS and EVENTS_END.
This sample assumes a radio stack (e.g, BLE) will configure and enable the radio in our place.

On nRF53, as the PPI configuration is defined in the RADIO peripheral, modifying it might break radio stacks that depend on that PPI configuration. You should instead find out what channel will be used by the stack and subscribe to it. Here we assume channels 5 for START and 6 for END.

```c
##if defined(NRF_DPPIC_NS)
##define NRF_GPIOTE NRF_GPIOTE_NS
##define NRF_RADIO  NRF_RADIO_NS
##define CHANNEL_START 5
##define CHANNEL_END   6
##else
##define CHANNEL_START 16
##define CHANNEL_END   17
##endif

##define OUTPIN  10

/* Configure output pin */
NRF_P0->DIRSET = (1 << OUTPIN);
NRF_P0->OUTCLR = (1 << OUTPIN);

/* Configure GPIOTE */
NRF_GPIOTE->CONFIG[2] = 3; /* Task mode */
NRF_GPIOTE->CONFIG[2] |= 1 << (8 + OUTPIN); /* Pin 10 */
NRF_GPIOTE->CONFIG[2] |= 0 << 13; /* Port 0 (line not necessary for P0) */
NRF_GPIOTE->CONFIG[2] |= 3 << 16; /* Toggle pin on TASKS_OUT */
NRF_GPIOTE->CONFIG[2] |= 0 << 20; /* Initial pin value is LOW */

/* Link RADIO and GPIOTE using (D)PPI */
##if defined(NRF_DPPIC_NS)

/* We don't write to the RADIO peripheral as it might
 * be cleared by the radio stack. Instead, we assume
 * a fixed channel will be configured. */

// NRF_RADIO->PUBLISH_ADDRESS = CHANNEL_START | (1 << 31);
NRF_GPIOTE->SUBSCRIBE_SET[2]  = CHANNEL_START | (1 << 31);
NRF_DPPIC_NS->CHENSET         = 1 << CHANNEL_START;

// NRF_RADIO->PUBLISH_END    = CHANNEL_END | (1 << 31);
NRF_GPIOTE->SUBSCRIBE_CLR[2] = CHANNEL_END | (1 << 31);
NRF_DPPIC_NS->CHENSET        = 1 << CHANNEL_END;
##else

NRF_PPI->CH[CHANNEL_START].EEP = &NRF_RADIO->EVENTS_ADDRESS;
NRF_PPI->CH[CHANNEL_START].TEP = &NRF_GPIOTE->TASKS_SET[2];
NRF_PPI->CHENSET               = 1 << CHANNEL_START;

NRF_PPI->CH[CHANNEL_END].EEP = &NRF_RADIO->EVENTS_END;
NRF_PPI->CH[CHANNEL_END].TEP = &NRF_GPIOTE->TASKS_CLR[2];
NRF_PPI->CHENSET             = 1 << CHANNEL_END;
##endif
```

## Execution context

Execution context tracing is useful for ISR profiling and resolving concurrency bugs.

Most systems will have some level of RTOS integration, showing:
- Threads and ISRs being switched in and out
- Why a thread is switched out / blocked
- Operations on kernel objects (semaphores, fifos etc)

### Zephyr/Linux CTF

Common Trace Format is a binary tracing event format, used in Zephyr and the linux kernel.
The binary stream can then be processed by CLI (babeltrace) and GUI (tracecompass) applications

Zephyr has an implementation, but [others are available](https://barectf.org/docs/barectf/3.0/index.html).

#### Example usage

We will use the basic/threads sample: zephyr/samples/basic/threads/src/main.c

Install the babeltrace2 python bindings:
`sudo apt install -y babeltrace2`

- Enable CTF output on UART

`zephyr/samples/basic/threads/prj.conf`
```
## Free up UART
CONFIG_PRINTK=n
CONFIG_BOOT_BANNER=n
CONFIG_UART_CONSOLE=n
CONFIG_LOG_BACKEND_UART=n

## Enable tracing subsys + CTF
CONFIG_TRACING=y
CONFIG_TRACING_CTF=y
CONFIG_TRACING_ASYNC=y
CONFIG_TRACING_BUFFER_SIZE=8192

## Redirect output to UART
CONFIG_SERIAL=y
CONFIG_TRACING_BACKEND_UART=y
```

- Add a device tree overlay for the board:

`zephyr/samples/basic/threads/boards/nrf52840dk_nrf52840.overlay`
```
/ {
       chosen {
               zephyr,tracing-uart = &uart0;
       };
};
```

- Recover the board (to ensure no garbage on UART)

```
nrfjprog --recover --snr 683485890
```

- Run a script to capture the output:

``` shell
## from the zephyr repo root
python ./scripts/tracing/trace_capture_uart.py -d /dev/ttyACM3 -b 115200
```

- Flash: `west flash -i 683485890`

- Interrupt the script (Ctrl-C) once enough time has passed

- Create a folder with the  configuration files and the captured data

``` shell
## from the zephyr repo root
mkdir -p ctf
cp subsys/tracing/ctf/tsdl/metadata ctf/
cp channel0_0 ctf/
```

- Invoke the parsing script and print the results

``` shell
## from the zephyr repo root
john@jori-pc:~/repos/zephyrproject/zephyr$ python3 ./scripts/tracing/parse_ctf.py -t ctf
1970-01-01 01:00:00.394012 (+0.000000 s): timer_init
1970-01-01 01:00:00.394043 (+0.000031 s): timer_start
1970-01-01 01:00:00.394073 (+0.000031 s): thread_create: unknown
1970-01-01 01:00:00.394073 (+0.000000 s): thread_info (Stack size: 1024)
1970-01-01 01:00:00.394135 (+0.000061 s): thread_name_set
1970-01-01 01:00:00.394165 (+0.000031 s): thread_create: blink0_id
1970-01-01 01:00:00.394165 (+0.000000 s): thread_info (Stack size: 1024)
1970-01-01 01:00:00.394196 (+0.000031 s): thread_create: blink1_id
1970-01-01 01:00:00.394226 (+0.000031 s): thread_info (Stack size: 1024)
1970-01-01 01:00:00.394257 (+0.000031 s): thread_create: uart_out_id
1970-01-01 01:00:00.394257 (+0.000000 s): thread_info (Stack size: 1024)
1970-01-01 01:00:00.394318 (+0.000061 s): thread_switched_out: main
1970-01-01 01:00:00.394348 (+0.000031 s): thread_switched_in: main
1970-01-01 01:00:00.394379 (+0.000031 s): thread_switched_out: main
1970-01-01 01:00:00.394379 (+0.000000 s): thread_switched_in: blink0_id
1970-01-01 01:00:00.394470 (+0.000092 s): thread_switched_out: blink0_id
1970-01-01 01:00:00.394501 (+0.000031 s): thread_switched_in: blink1_id
1970-01-01 01:00:00.394562 (+0.000061 s): thread_switched_out: blink1_id
1970-01-01 01:00:00.394592 (+0.000031 s): thread_switched_in: uart_out_id
1970-01-01 01:00:00.394653 (+0.000061 s): thread_switched_out: uart_out_id
1970-01-01 01:00:00.394684 (+0.000031 s): thread_switched_in: tracing_thread
1970-01-01 01:00:00.447083 (+0.052399 s): thread_switched_out: tracing_thread
1970-01-01 01:00:00.447083 (+0.000000 s): timer_start
1970-01-01 01:00:00.447113 (+0.000031 s): thread_switched_in: idle
1970-01-01 01:00:00.447144 (+0.000031 s): idle
1970-01-01 01:00:00.494049 (+0.046906 s): isr_enter
1970-01-01 01:00:00.494080 (+0.000031 s): isr_exit
1970-01-01 01:00:00.494080 (+0.000000 s): idle
1970-01-01 01:00:00.494507 (+0.000427 s): isr_enter
1970-01-01 01:00:00.494537 (+0.000031 s): isr_exit
1970-01-01 01:00:00.494568 (+0.000031 s): thread_switched_out: idle
1970-01-01 01:00:00.494568 (+0.000000 s): thread_switched_in: blink0_id
1970-01-01 01:00:00.494659 (+0.000092 s): thread_switched_out: blink0_id
1970-01-01 01:00:00.494690 (+0.000031 s): thread_switched_in: uart_out_id
...
```

#### Custom event

We can add custom tracing event in addition to the built-in ones.
Here's how to add a basic `puts`-like event:

Define a new event in the metadata description:

`zephyr/subsys/tracing/ctf/tsdl/metadata`
```
event {
	name = log;
	id = 0x34;
	fields := struct {
		ctf_bounded_string_t payload[20];
	};
};
```

Copy over the new metadata in the capture folder:

```
cp subsys/tracing/ctf/tsdl/metadata ctf/
```

Add the event ID in the CTF event struct:
`zephyr/subsys/tracing/ctf/ctf_top.h (in ctf_event_t)`

``` c
	CTF_EVENT_LOG = 0x34
```

Add a formatting function to send the event:
`zephyr/subsys/tracing/ctf/ctf_top.h`
``` c
static inline void ctf_top_log(char* data)
{
	ctf_bounded_string_t payload;

	strncpy(payload.buf, data, sizeof(payload.buf));
	CTF_EVENT(CTF_LITERAL(uint8_t, CTF_EVENT_LOG), payload);
}
```

Log something, in our case, the function and the current thread name:
`zephyr/samples/basic/threads/src/main.c (in blink()'s inner while loop)`
``` c
		char a[20];
		snprintf(a, sizeof(a), "%s [%s]", __func__, k_current_get()->name);
		ctf_top_log(a);
```

Add support for the new event in the parsing script:

``` python
        # Towards the end of zephyr/scripts/tracing/parse_ctf.py:

        elif event.name in ['log']:
            c = Fore.RED
            print(c + f"{dt} (+{diff_s:.6f} s): {event.name}: {event.payload_field['payload']}" + Fore.RESET)
```

Run the parsing script, see the custom log event:

``` shell
1970-01-01 01:00:00.391052 (+0.000092 s): log: blink [blink0_id]
```

### Segger SystemView

SystemView is a commercial real-time event recording and visualization tool made by Segger.

It has an excellent GUI, but I had some stability issues in the past, so it is advised to save the trace before attempting to use the GUI too much (zooming etc).

#### Basic usage

Zephyr has a tracing backend for systemview, although it is seldom updated and can be broken from time to time.
It might be necessary to disable kernel events that are not yet implemented in that backend.

An advantage it has over CTF is that it uses Segger RTT as a communication channel, freeing up the UART for the application console. This is not a technical limitation, one could write a CTF backend for RTT, SPI or even ITM but it doesn't exist right now.

We will use the same sample to test out systemview:
`zephyr/samples/basic/threads/src/main.c`

1. Download and install SystemView for your OS: [Product page](https://www.segger.com/products/development-tools/systemview/)

2. Open and configure SystemView:
- [Target] -> [Recorder Configuration]
- Select "J-Link", click ok, new dialog opens
- Select "USB" type, input probe/DK serial number
- Click the "..." in "Target Connection", select the right SoC
- (optional) increase interface speed to 8000 kHz
- Click ok

3. Enable tracing with the SystemView backend:
`zephyr/samples/basic/threads/prj.conf`
```
## Enable tracing subsys + SystemView backend
CONFIG_TRACING=y
CONFIG_TRACING_SYNC=y
CONFIG_SEGGER_SYSTEMVIEW=y
CONFIG_SEGGER_SYSTEMVIEW_BOOT_ENABLE=y
CONFIG_SEGGER_SYSVIEW_RTT_BUFFER_SIZE=16134
```

4. Build sample and flash device
5. Start recording in SystemView: click the "play" button in the top-left corner
6. Inspect the trace using the GUI. The timeline view can be very useful.
7. See the documentation ([Help] -> [User guide]) for how to use the GUI.

- Don't forget to stop recording before attempting to reflash the device.

#### Delimited tracing

If you followed the previous instructions, you probably saw an "Overflow events detected" error show up in systemview.
This means that the destination buffer was full and couldn't store any more data. It can be because the system has ran for too long before starting recording in the GUI, or also because events are being stored faster than the transport's bandwidth.

This can be solved by not starting the capture on boot, but rather in a specific part of the code. The capture can then be stopped once the code section that needs to be instrumented is over.
They can only be called once, i.e., the capture cannot be paused.

- include the systemview header: `#include <SEGGER_SYSVIEW.h>`
- start capture: `SEGGER_SYSVIEW_Start();`
- stop capture: `SEGGER_SYSVIEW_Stop();`

One can get creative, and put the start/stop functions in peripheral ISRs or wrap them with if statements. For example we could start capturing only when we get a packet on the radio with a specific length, or when a button is pressed on the DK.

#### Custom event

I won't show how to add a custom event, only how to achieve the same thing as the CTF example, which is logging a string:

Just call the `SEGGER_SYSVIEW_Print()` function!

``` c
		char a[20];
		snprintf(a, sizeof(a), "%s [%s]", __func__, k_current_get()->name);
		SEGGER_SYSVIEW_Print(a);
```

The messages now show up along the other events in the main view, and also in the "Terminal" pane.

### Others

Other systems exists, for example from Lauterbach or Percepio.
Zephyr has some support for [Percepio Tracealyzer](https://percepio.com/tracealyzer/tracealyzer-for-zephyr/getting-started-with-tracealyzer-for-zephyr-rtos/); this is also expensive software (around 2k USD per seat).

## Instruction tracing

The only way to observe the CPU without disturbing it is by using an instruction tracer.
On ARM this is achieved with the ETM + a fast debug probe that supports parallel trace output.

This kind of tracing will log every single instruction executed on the CPU, without any overhead.

Some ARM application processors also support data tracing, but the Cortex-M series don't.

### Flame graph

A very useful profiling tool is the so-called "flame graph", which shows the execution time of every function, along with its call stack (as a sort of pyramid, or flame).
This allows us to verify assumptions about code paths and instantly identify possible optimization spots.

### Hardware configuration

Most nRF development kits have an unpopulated 19/20-pin header that exposes the TRACE pins.
A male header needs to be soldered in so the probe can connect to it.

Additionally, there can be some pins that are shared with other functionality.
We will assume an nRF52840 DK. Finding this on other boards is left as an exercise to the reader.
The pin map is described [in the infocenter](https://infocenter.nordicsemi.com/topic/ug_nrf52840_dk/UG/dk/hw_debug_in_trace.html).

We need to slide the TRACE switch (SW7) to the 'Alt' position.
Then we need to tell our application/zephyr to not use these GPIOs anymore, and use the replacement.

### Software configuration

The CPU startup file in the MDK needs to be told to enable the tracing port.
This is achieved by defining `ENABLE_TRACE`.

In zephyr, the build system can emit that define when setting `CONFIG_NRF_TRACE_PORT=y`.

We can apply this configuration:
`zephyr/samples/basic/threads/prj.conf`
```
## Enable trace port
CONFIG_NRF_TRACE_PORT=y
## Enable monitor, so Ozone can show the threads view
CONFIG_THREAD_MONITOR=y

## Disable UART to get less unwanted traces
CONFIG_SERIAL=n
CONFIG_UART_CONSOLE=n
CONFIG_LOG_BACKEND_UART=n
```

Then re-route the two pushbuttons to the alternative GPIOs (as per the infocenter).
`zephyr/samples/basic/threads/boards/nrf52840dk_nrf52840.overlay`
```
&button0 {
	gpios = < &gpio1 0x7 0x11 >;
	label = "Push button switch 0";
};
&button1 {
	gpios = < &gpio1 0x8 0x11 >;
	label = "Push button switch 1";
};

```

### J-Trace configuration

The probe we will be using is the [J-Trace PRO Cortex-M](https://www.segger.com/products/debug-probes/j-trace/models/j-trace/).
It retails for around 1500 USD, and includes a Segger Ozone (debugger) license (a bargain IMO).

Connect it to the computer, and the DK, the (Power, USB and Target Power) LEDs should light up.

Download and install [Segger Ozone](https://www.segger.com/products/development-tools/ozone-j-link-debugger/).

* Create a new project using the wizard
* Select the correct device and register set
* Select the peripherals .svd file (can be found in the MDK, optional)
* Click next
* Select SWD interface, 4MHz (for 840DK)
* Select USB and click on the j-trace ID to populate serial num field
* Click next
* Point to the correct .elf file (should be `zephyr/samples/basic/threads/build/zephyr/zephyr.elf`)
* Click next, and finish

* Go to Tools -> Trace Settings
* Select "Trace Pins" as source
* Input correct CPU frequency (64MHz for nRF52840)
* Select 4-bit port width
* Increase instruction count to >100M
* Click OK

* Show the "Instruction Trace", "Timeline" and "Code Profile" under View
* Arrange the workspace to something you like and save the project
* Click the green button to download and connect to target
* Start execution, you should see the "Instruction trace" view being updated
* Stop execution
* "Instruction Trace" is populated with the latest instructions
* "Timeline" now has the flame graph

### Search the trace

- Right-click in "Instruction trace" or the code view, select "Find in Trace".
- Enter the string to look up.
- Tick (at least) the "Function header" tickbox under the "Look where" section.
- Click "Find all".
- A "Find Results" window appears with the results.
- Double-clicking opens the function's instructions in the "Instruction trace" and syncs to the "Timeline".

### Trigger ranges

Triggering on a specific block of code is supported from the GUI, but has to be
"helped" by adding a `__NOP()` at the start and end of the block. Else, it might not have an instruction to hook into because of optimizations.

In the code view, right-click to the left of the line number, select "Set Tracepoint (Start)".
Do the same, but selecting "Set Tracepoint (Stop)" at the end of the block.

The trace should only trigger on the enclosed instructions now.

### Limitations

The interface speed can be a bottleneck, if the CPU executes too many instructions in a short time, it can lead to the trace getting lost.

## Other tools

In order to iterate faster, it might be better to try and isolate the problem.
Making a quick test can be the solution.
Also comes with a bonus, as this test can be added to the list of tests ran in regression, making sure this particular bug doesn't show itself ever again.

### Unit-testing

If the bug seems to be a logic bug, unit-testing can save a lot of time. Unit-testing is good because
- results should deterministic
- anything not related to the unit is not present in the image
- test execution should be near-instant, speeding up iteration time.

### Zephyr & native_posix

Zephyr has a `native_posix` board that builds an image that can be run like any other executable on POSIX OSes.
This is good because:
- Execution speed is much higher (GHz > MHz)
- Vastly more memory to try stuff out
- Output to `stdout`, don't need any hardware to set up tracing
- Automatic, e.g. `git bisect` and a debugger run is much faster than a `compile-flash-attach` cycle on HW

Most tests in zephyr CI are run on `native_posix`.

### Babblesim

Zephyr also has a `nrf52_bsim` board that is `native_posix` + peripheral emulation + [Babblesim](https://babblesim.github.io/) PHY simulator.

This is used to run Bluetooth tests at native speeds, and has the same advantages as `native_posix`.
The big one is that the PHY/airspace is deterministic.

Zephyr has a bunch of babblesim tests for Bluetooth: `zephyr/tests/bluetooth/bsim_bt/README.txt`.
