# VSync demo: Concurrent `cat`

This demo has two goals: first, to give an example of how weak memory
consistency can affect the visible outcome of a concurrent program; second,
to demonstrate how to use [vsyncer](https://github.com/open-s4c/vsyncer)
to verify and optimize the barriers of that program.

Each goal is served by one part of the demo. Both parts can be run
independently and have different tooling requirements.

You can see pre-recorded videos of the demo in asciinema:
[part 1](https://asciinema.org/a/q7048o135HVyhHcuL4bxTzDNR)
and
[part 2](https://asciinema.org/a/wL8MzF1kex4ApcHrXooYONsLK).

---

## Part 1: Monalisa

In the first part of the demo, we construct `ccat`, a simple concurrent `cat`
program that, as the original `cat` program, reads a file from the filesystem
and writes its contents to `stdout`.  However, `ccat` just contains enough
features to allow us to show the issues with weak memory consistency; it
cannot open multiple files, it does not read `stdin`.

The program consists of a producer thread and a consumer thread connected
by a ring buffer.  The producer opens a file (we will use an image of
Monalisa from Wikipedia), reads the file page-by-page, cuts each page
in small chunks, and write the pointer to each chunk into the ringbuffer.
The consumer dequeues the pointers to the page chunks and writes to `stdout`
their content, one-by-one, in FIFO order.

To show a failure, we calculate the checksum of the input image and the
output image. When they differ we can also visualize both images to look
for visible differences; often the differences are obvious.

---

### Setup

To compile the program `ccat`, you'll need `clang` or `gcc` and `make`. To
view the image files, open them with your favorite image viewer.

We provide a script that repeatedly calls `./ccat assets/monalisa.jpg >
output.jpg`, compares the checksum of both files (computed with `md5sum`),
and aborts in case the checksums differ.  If your system has ImageMagick's
`convert` and [viu](https://github.com/atanunq/viu) in the executable path,
the script will show the mismatching figures side-by-side.

### Compiling

To compile `ccat`, call `make`.  You can test the program with
with `./ccat README.md`.  We will use the `assets/monalisa.jpg`
as a running example. The Monalisa file is a resized version of [this
file](https://upload.wikimedia.org/wikipedia/commons/e/ec/Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg)
from Wikipedia.

Now, you can run `scripts/run.sh assets/monalisa.jpg`. In a few seconds,
a different pair of figures should appear.

---

### Issue 1: Ring buffer does not support multiple threads

Initially, `ccat` is using a version of the ring buffer that is implemented
for single threads. One can inspect the file `ringbuf.h` and try to fix
it. On every fix iteration, do not forget to recompile `ccat` and run the
script again.

One possible outcome of "fixing" `ringbuf.h` might be what is in
`ringbuf_spsc_plain.h`.  You can change the include path inside `ccat.c`
to use this file instead of `ringbuf.h`. This implementation should work on
x86 machines, and the script will not terminate.

TODO: script should gracefully terminate after a timeout.

---

### Issue 2: Ring buffer does not work on weak memory

If you have access to some machine with weak memory consistency, such as a
Raspberry Pi 4, you can try running `ccat` with `ringbuf_spsc_plain.h`.

> Note: These issues should also be reproducible on several Arm-based
smartphones as well as on Apple M1-3 processors.

When running on such system, `ccat` might corrupt `monalisa.jpg` in similar
ways as int the first experimet. The reason is that the CPU can reorder
memory accesses, reverting the fixes introduced when going from `ringbuf.h`
to `ringbuf_spsc_plain.h`.

To fix the reordering issues, we **must** use atomic operations. The file
`ringbuf_spsc.h` contains the same implementation but now using atomic
operations from [libvsync](https://github.com/open-s4c/libvsync) on every
racy access.

---

### Issue 3: The barriers are too strong

The resulting code uses the strongest barriers on every racy access. How to
optimize this code (relaxing barriers), without breaking its correctness?

We can try to manually do that, but it is error prone. Try it out, running
the newly compiled `ccat` with the script on an ARMv8 machine.

The answer should be given in part 2 of this demo.

### Issue 4: Using TSAN

Note that if you compile `ccat.c` with `-fsanitize=thread`, TSAN will report
false positive races in the access to the array in the enqueue and dequeue
functions, even if you are using strong barriers. The reason is that TSAN
does not understand weak memory. Wiith `vsyncer` we should be able to use
data race as a reliable indicator of concurrency issues.

---

## Part 2: vsyncer

We now explore the `vsyncer` tool and how it can help us to verify and
optimize our ring buffer on weak memory models.

### Setup

Install [vsyncer](https://github.com/open-s4c/vsyncer) following the
instructions in the `README.md`.  This part of the demo should also work on
Windows with [Docker Desktop](Thttps://www.docker.com/products/docker-desktop)
installed.  Opening the terminal, run the script to configure your shell.
On bash, run

    . env/vsyncer.sh

On PowerShell, run

    & env\vsyncer.ps1

---

### Issue 1: Verifying the ring buffer

One of the big limitations of model checkers is that we need to simplify
the client code to make it manageable for the tool. In this demo we already
provide such a client code: `verify-spsc.c`.

Change the include line in the file to verify different variants of the
ringbuffer.  Here is the command to verify the code:

    vsyncer check src/verify-spsc.c

If you are using an implementation with atomic variables, you can also change
the barriers from the command line, for example, making them all relaxed:

    vsyncer check -A 0 src/verify-spsc.c

---

### Issue 2: Optimizing the ring buffer

Select an implementation with strong barriers and then run

    vsyncer optimize src/verify-spsc.c

Once the optimization is finished, you will get a report with the changes
that can be applied to the source code. Do them and subsequently try running
`ccat` with this optimized ring buffer on an ARMv8 machine.

---

### Issue 3: Advanced example

For the interested user, we also provide a multi-producer/multi-consumer ring
buffer. The verification of this code takes about 5 minutes on an ordinary
laptop and the optimization may take up to 20 minutes.

---

## Acknowledgements

This demo is part of the Open Harmony Research Tutorial at ASPLOS'24.
We thank the support of the [OpenHarmony Concurrency & Coordination TSG
(Technical Support Group), 并发与协同TSG][tsg].

The major heavy lifting in this demo is done by
[Dartagnan](https://github.com/hernanponcedeleon/Dat3M), the model checker
backend of `vsyncer`.  We thank [Thomas Haas](https://github.com/ThomasHaas)
for his constant support in improving Dartagnan to work with `vsyncer`.

[tsg]: https://www.openharmony.cn/techCommittee/aboutTSG

