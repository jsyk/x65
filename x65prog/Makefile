include config.mk

ifeq ($(STATIC),1)
LDFLAGS += -static
LDLIBS += $(shell for pkg in libftdi1 libftdi; do $(PKG_CONFIG) --silence-errors --static --libs $$pkg && exit; done; echo -lftdi; )
CFLAGS += $(shell for pkg in libftdi1 libftdi; do $(PKG_CONFIG) --silence-errors --static --cflags $$pkg && exit; done; )
else
LDLIBS += $(shell for pkg in libftdi1 libftdi; do $(PKG_CONFIG) --silence-errors --libs $$pkg && exit; done; echo -lftdi; )
CFLAGS += $(shell for pkg in libftdi1 libftdi; do $(PKG_CONFIG) --silence-errors --cflags $$pkg && exit; done; )
endif

all: $(PROGRAM_PREFIX)x65prog$(EXE) $(PROGRAM_PREFIX)x65icd$(EXE)

$(PROGRAM_PREFIX)x65prog$(EXE): x65prog.o mpsse.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LDLIBS)

$(PROGRAM_PREFIX)x65icd$(EXE): x65icd.o mpsse.o
	$(CC) -o $@ $(LDFLAGS) $^ $(LDLIBS)

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp $(PROGRAM_PREFIX)x65prog$(EXE) $(DESTDIR)$(PREFIX)/bin/$(PROGRAM_PREFIX)x65prog$(EXE)
	cp $(PROGRAM_PREFIX)x65icd$(EXE) $(DESTDIR)$(PREFIX)/bin/$(PROGRAM_PREFIX)x65icd$(EXE)

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(PROGRAM_PREFIX)x65prog$(EXE)
	rm -f $(DESTDIR)$(PREFIX)/bin/$(PROGRAM_PREFIX)x65icd$(EXE)

clean:
	rm -f $(PROGRAM_PREFIX)x65prog
	rm -f $(PROGRAM_PREFIX)x65prog.exe
	rm -f $(PROGRAM_PREFIX)x65icd
	rm -f $(PROGRAM_PREFIX)x65icd.exe
	rm -f *.o *.d

-include *.d

.PHONY: all install uninstall clean

