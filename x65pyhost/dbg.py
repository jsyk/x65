#!/usr/bin/python3
import x65ftdi
from icd import *
from cpuregs import *
from cpuidec import *

from rich.syntax import Syntax
from rich.table import Table

from textual.app import App, ComposeResult
from textual.containers import ScrollableContainer, HorizontalScroll, VerticalScroll, Grid
from textual.widgets import Button, Footer, Header, Static, RichLog, DataTable, Label
from textual.timer import Timer


class CpuRegView(HorizontalScroll):
    """ CPU Registers View """
    def compose(self) -> ComposeResult:
        yield DataTable(id='cpuregtb')
    
    def on_ready(self) -> None:
        """Called  when the DOM is ready."""
        self.regtb = self.query_one('#cpuregtb')
        # It will look like this:
        #   Bank  .H.L  REG     Decode
        #   $01  $....  DBR.X
        #   $01  $....  DBR.Y
        #        $....  A
        #   $00  $....  SP
        #   $..  $....  PBR.PC
        #   $00  $....  DPR
        #        $..    FL       --1B-I--/emu
        # create columns
        self.col_Bank = self.regtb.add_column("Bank")
        self.col_HL = self.regtb.add_column(".H.L")
        self.col_Name = self.regtb.add_column("[green]CPU REG[/green]")
        self.col_Decode = self.regtb.add_column("Decode        ")
        # create rows - for each register
        self.reg_X = self.regtb.add_row('$..', '$....', 'DBR.X', '')
        self.reg_Y = self.regtb.add_row('$..', '$....', 'DBR.Y', '')
        self.reg_A = self.regtb.add_row('',    '$....', 'A', '')
        self.reg_SP = self.regtb.add_row('$00','$....', 'SP', '')
        self.reg_PC = self.regtb.add_row('$..','$....', 'PBR.PC', '')
        self.reg_DPR = self.regtb.add_row('',  '$....', 'DPR', '')
        self.reg_Flags = self.regtb.add_row('',  '$..', 'Flags', '')

    
    def update(self, regs: CpuRegs) -> None:
        # X reg
        self.regtb.update_cell(self.reg_X, self.col_Bank, '${:02x}'.format(regs.DBR))
        self.regtb.update_cell(self.reg_X, self.col_HL, '${}{:02x}'.format(regs.hex2(regs.XH), regs.XL))
        # Y reg
        self.regtb.update_cell(self.reg_Y, self.col_Bank, '${:02x}'.format(regs.DBR))
        self.regtb.update_cell(self.reg_Y, self.col_HL, '${}{:02x}'.format(regs.hex2(regs.YH), regs.YL))
        # A reg
        self.regtb.update_cell(self.reg_A, self.col_HL, '${}{:02x}'.format(regs.hex2(regs.AH), regs.AL))
        # SP reg
        self.regtb.update_cell(self.reg_SP, self.col_HL, '${:04x}'.format(regs.SP))
        # PBR.PC reg
        self.regtb.update_cell(self.reg_PC, self.col_Bank, '${:02x}'.format(regs.PC >> 16))
        self.regtb.update_cell(self.reg_PC, self.col_HL, '${:04x}'.format(regs.PC & 0xffff))
        # DPR
        self.regtb.update_cell(self.reg_DPR, self.col_HL, '${:04x}'.format(regs.DPR))
        # Flags
        self.regtb.update_cell(self.reg_Flags, self.col_HL, '${:02x}'.format(regs.FL))
        self.regtb.update_cell(self.reg_Flags, self.col_Decode, '{}{}{}{}{}{}{}{}/{}'.format(
            'N' if regs.FL & 128 else '-',
            'V' if regs.FL & 64 else '-',
            '1' if regs.EMU else ('m' if self.FL & 32 else 'M'),
            'B' if regs.EMU and (regs.FL & 16) else ('-' if regs.EMU else ('x' if regs.FL & 16 else 'X')),
            'D' if regs.FL & 8 else '-',
            'I' if regs.FL & 4 else '-',
            'Z' if regs.FL & 2 else '-',
            'C' if regs.FL & 1 else '-',
            'emu' if regs.EMU else 'Nat'))
        


class DebuggerApp(App):
    """A Textual app to debug X65."""

    BINDINGS = [("r", "run_stop_cpu", "Run/Stop"), 
                ("s", "step_cpu", "Step"),
                ("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        """Create child widgets for the app."""
        yield Header()
        yield Footer()
        with HorizontalScroll():
            yield DataTable(id="trace", classes="box")
            with VerticalScroll():
                yield Label("Status:", id="targetstatus")
                yield CpuRegView(id='cpuregs')
            
        # yield RichLog(markup=True)

        self.cycle_i = 0                 # CPU Cycles counter
        self.tracetb_row_preview = None


    def on_ready(self) -> None:
        """Called  when the DOM is ready."""
        # text_log = self.query_one(RichLog)
        # text_log.write(Syntax(CODE, "python", indent_guides=True))
        # rows = iter(csv.reader(io.StringIO(CSV)))
        # table = Table(*next(rows))
        # for row in rows:
        #     table.add_row(*row)
        # text_log.write(table)
        # text_log.write("[bold magenta]Write text or any Rich renderable!")
        # text_log.write("")
        # self.timer = Timer(event_target=self, interval=0.5)
        self.statuslabel = self.query_one("#targetstatus")

        self.tracetb = self.query_one('#trace')
        self.tracetb.add_column("Cycle#")
        self.tracetb.add_column("MAH")
        self.tracetb.add_column("Area")
        self.tracetb.add_column("CBA")
        self.tracetb.add_column("CA")
        self.tracetb.add_column("CD")
        self.tracetb.add_column("ctr")
        self.tracetb.add_column("sta")
        self.tracetb.add_column("Instruction")

        self.cpuregs = self.query_one('#cpuregs')
        self.cpuregs.on_ready()
        # table.add_rows(ROWS[1:])
        # table.add_row(-255, 6, "(RAMB:134)", "$00", "$c1cd", "$6b", "$0f:----",  "$7d:r--NmXPDS", "[green]RTL[/green]")

        self.set_interval(0.5, self.on_timer)

   
    def on_timer(self) -> None:
        """ Called from interval timer, in main loop - assume ICD is accessible """
        # read the current trace register, without disturbing it
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(sample_cpu=True)
        self.statuslabel.update("Status: {}".format('CPU RUNs' if is_cpuruns else 'CPU Stopped' ))

        # check if trace buffer memory is non-empty, while CPU stopped
        if not is_cpuruns and is_tbr_valid:
            # yes, we should *first* print the trace buffer contents!
            # print the buffer out
            self.update_tracebuffer()
            

    def action_run_stop_cpu(self) -> None:
        """An action to run/stop the cpu."""
        # read the current trace register, without disturbing it
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(sample_cpu=True)
        if is_cpuruns:
            # CPU runs --> stop it!
            self.icd.cpu_ctrl(False, False, False)
        else:
            # CPU stopped --> run it: deactivate the reset, run the cpu
            self.icd.cpu_ctrl(True, False, False)
            # add line to the trace view
            # isnt there an 'preview'/'upcoming' row in the table?
            # if yes then we should remove it first, to replace with new data
            if self.tracetb_row_preview is not None:
                self.tracetb.remove_row(self.tracetb_row_preview)
                self.tracetb_row_preview = None
            
            self.tracetb.add_row("----", 
                                "----", "----", "----", "----", 
                                "----", "----", "----", "----")
            # move cursor to the last entry
            self.tracetb.move_cursor(row=self.tracetb.row_count)
        
    
    def action_step_cpu(self) -> None:
        """Action to step the CPU by 1 cc"""
        # self.dark = not self.dark
        # print("action_step_cpu called")
        # Now we should normally step the CPU by one cycle.
        # import pdb; pdb.set_trace()

        # # // deactivate the reset, STEP the cpu by 1 cycle
        # self.icd.cpu_ctrl(False, True, False, 
        #             force_irq=False, force_nmi=False, force_abort=False,
        #             block_irq=False, block_nmi=False, block_abort=False)
        # self.update_tracebuffer()

        # read the current trace register, without disturbing it
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(sample_cpu=True)
        if is_cpuruns:
            # CPU runs --> stop it!
            self.icd.cpu_ctrl(False, False, False)
            # print the buffer out
            self.update_tracebuffer()

        self.do_step_cpu(step_count = 1)              # step just 1 instruction (few cycles)


    def do_step_cpu(self, step_count: int) -> None:
        """ Step the CPU by step_count instructions. """
        # self.cycle_i = 0                 # CPU Cycles counter
        step_i = 0                  # CPU Stepped Instructions (each multiple cycles)
        cycles_without_step = 0     # how many cycles we are going without encountering an instruction (SYNC)
        # cpust_ini = CpuRegs()

        # for i in range(0, step_count+1):
        while step_i <= step_count:
            # on the very first iteratio we don't step so that we could lift out the trace buffer first.
            if self.cycle_i > 0:
                # Not the first cycle.
                # Was the instruction step count reached?
                if step_i == step_count:
                    # Yes => we should check the CPU state first and continue just if there is NOT a new instruction
                    # upcoming.
                    # read the current trace register
                    is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(sample_cpu=True)
                    # sanity check /assert:
                    if is_valid or is_cpuruns:
                        print("ERROR: Unexpected IS_VALID=TRUE or IS_CPURUNS=True: COMMUNICATION ERROR!!")
                        exit(1)
                    # We expect is_valid=False because this is not a trace reg from a finished CPU cycle.
                    # Instead, the command sample_cpu=True just samples the stopped CPU state before it is commited.
                    # Let's inspect it to see if this is already a new upcoming instruction, or contination of the old (last) one.
                    tbuf = ICD.TraceReg(rawbuf)
                    # is_sync = (tbuf[0] & ISYNC) == ISYNC
                    if tbuf.is_sync:
                        # new upcoming instruction & we have already reached the desired number of instruction steps => exit the loop here
                        # print()
                        # print("Upcoming:    ", end='')
                        # decode and print cycle line
                        self.print_traceline(self.cycle_i, tbuf, is_upcoming=True)
                        break
                
                # FIXME add
                # if args.force_opcode is not None:
                #     print("should force opcode {}".format(args.force_opcode))
                #     icd.cpu_force_opcode(int(args.force_opcode), False)
                
                # Now we should normally step the CPU by one cycle.
                # // deactivate the reset, STEP the cpu by 1 cycle
                self.icd.cpu_ctrl(False, True, False, 
                                  force_irq=False, force_nmi=False, force_abort=False,
                                  block_irq=False, block_nmi=False, block_abort=False)
                            # force_irq=args.force_irq, force_nmi=args.force_nmi, force_abort=args.force_abort,
                            # block_irq=args.block_irq, block_nmi=args.block_nmi, block_abort=args.block_abort)
            
            # ELSE: cycle==0 => on the very first iteration, the trace register read below is the last cycle
            # in the history. Cycles before that were recorded in the trace buffer, which is read right after that.
            
            # read the current (last) trace cycle register
            is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace()
            
            # check if trace buffer memory is non-empty
            if is_tbr_valid:
                # yes, we should *first* print the trace buffer contents!
                # sanity check: this could happen just on the first for-iteration!!
                if self.cycle_i > 0:
                    # we expected that is_tbr_valid==0 because we remove entries as we go.
                    print("IS_TBR_VALID=TRUE: COMMUNICATION ERROR!!")
                    exit(1)
                # print the buffer out
                self.print_tracebuffer()
            

            # finally, check if the original trace register was valid
            # print("Cyc #{:5}:  ".format(self.cycle_i), end='')
            
            if is_valid:
                # is this a beginning of next instruction?
                tbuf = ICD.TraceReg(rawbuf)
                # is_sync = (tbuf[0] & ISYNC) == ISYNC
                if tbuf.is_sync:
                    step_i += 1
                    cycles_without_step = 0
                # decode and print cycle line
                self.print_traceline(self.cycle_i, tbuf)
            else:
                # print("N/A")
                # sanity: this could happen just on the first for-iter!
                if self.cycle_i > 0:
                    print("IS_VALID=FALSE: COMMUNICATION ERROR!!")
                    exit(1)

            # if cycle_i == 0:
            #     # first iteration; all history up to here was printed.
            #     # Now we can get the current CPU registers
            #     cpust_ini.cpu_read_regs(icd)
            #     print(cpust_ini)

            self.cycle_i += 1
            cycles_without_step += 1

            if cycles_without_step > 32:
                print("ERROR: {} CPU cycles without a new instruction! Is CPU stopped?".format(cycles_without_step))
                break

            # read_print_trace(banks)

        # FIXME add back
        # Show the final CPU State (regs)
        cpust_fin = CpuRegs()
        if cpust_fin.cpu_read_regs(self.icd):
            # print(cpust_fin)
            self.cpuregs.update(cpust_fin)
        else:
            print("ERROR: CPU State read failed!!")

        # move cursor to the last entry
        self.tracetb.move_cursor(row=self.tracetb.row_count)


    # def _on_idle(self) -> None:
    #     """Called when the app is idle."""
    #     print("Idle")

    def update_tracebuffer(self):
        """ Check if HW has a valid tracebuffer entries and extract them. """
        # read the current (last) trace cycle register
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace()

        # print("update_tracebuffer: is_tbr_valid={}".format(is_tbr_valid))

        # check if trace buffer memory is non-empty
        if is_tbr_valid:
            # yes, we should *first* print the trace buffer contents!
            self.cycle_i = 0
            # print the buffer out
            self.print_tracebuffer()
            # move cursor to the last entry
            self.tracetb.move_cursor(row=self.tracetb.row_count)


    def print_tracebuffer(self):
        """ Retrieve the complete trace buffer from HW and run print_traceline() over it. """
        # retrieve line from trace buffer
        is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(tbr_deq=True)
        rbuf_list = []
        while is_tbr_valid:
            # note down
            rbuf_list.append(rawbuf)
            # fetch next trace item into reg
            is_valid, is_ovf, is_tbr_valid, is_tbr_full, is_cpuruns, rawbuf = self.icd.cpu_read_trace(tbr_deq=True)
        # print out
        for i in range(0, len(rbuf_list)):
            # print("Cyc #{:5}:  ".format(i - len(rbuf_list)), end='')
            cycle_nr = i - len(rbuf_list)
            tbuf = ICD.TraceReg(rbuf_list[i])
            self.print_traceline(cycle_nr, tbuf)


    def print_traceline(self, cycle_nr, tbuf: ICD.TraceReg, is_upcoming=False):
        """ Decode the given tbuf instruction and append it to the tracetb widget. """
        # decode instruction in the trace buffer
        disinst = decode_traced_instr(self.icd, tbuf, is_upcoming)

        # IO area is between 0x9F00 and 0x9FFF of the CPU memory map
        IO_START_ADDR = 0x9F00          # TODO: move to common!
        IO_END_ADDR = 0x9FFF

        # extract signal values from trace buffer array
        CBA = tbuf.CBA  #tbuf[6]           # CPU Bank Address (816 topmost 8 bits; dont confuse with CX16 stuff!!)
        MAH = tbuf.MAH  #tbuf[5]           # Memory Address High = Physical 8kB Page in SRAM
        CA = tbuf.CA  #tbuf[4] * 256 + tbuf[3]        # CPU Address, 16-bit
        CD = tbuf.CD  #tbuf[2]                # CPU Data
        is_sync = tbuf.is_sync  #(tbuf[0] & ISYNC) == ISYNC
        is_io = (CA >= IO_START_ADDR and CA <= IO_END_ADDR)
        is_write = not tbuf.is_read_nwrite  #not(tbuf[0] & TRACE_FLAG_RWN)
        is_addr_invalid = not(tbuf.is_vpa or tbuf.is_vda)   # not((tbuf[0] & TRACE_FLAG_SYNC_VPA) or (tbuf[0] & TRACE_FLAG_VDA))
        mah_area = ICD.MAHDecoded.from_trace(MAH, CBA, CA).area_name

        ctr = "${:02x}:{}{}{}{}".format(tbuf.ctr_flags, 
                ('-' if tbuf.is_resetn else 'R'),
                ('-' if tbuf.is_irqn else 'I'),
                ('-' if tbuf.is_nmin else 'N'),
                ('-' if tbuf.is_abortn else '[red]A[/red]'))
        sta = "${:02x}:{}{}{}{}{}{}{}{}{}".format(tbuf.sta_flags, 
                ('r' if tbuf.is_read_nwrite else '[red]W[/red]'), 
                ('-' if tbuf.is_vectpull else '[yellow]v[/yellow]'),        # vector pull, active low
                ('-' if tbuf.is_mlock else 'L'),           # mem lock, active low
                ('e' if tbuf.is_emu8 else '[blue]N[/blue]'),        # 'e': emulation mode, active high; 'N' native mode
                ('m' if tbuf.is_am8 else '[blue]M[/blue]'),    # '816 M-flag (acumulator): 0=> 16-bit 'M', 1=> 8-bit 'm'
                ('x' if tbuf.is_xy8 else '[blue]X[/blue]'),    # '816 X-flag (index regs): 0=> 16-bit 'X', 1=> 8-bit 'x'
                ('P' if tbuf.is_vpa else '-'),        # '02: SYNC, '816: VPA (valid program address)
                ('D' if tbuf.is_vda else '-'),             # '02: always 1, '816: VDA (valid data address)
                ('S' if is_sync else '-'))

        # isnt there an 'preview'/'upcoming' row in the table?
        # if yes then we should remove it first, to replace with new data
        if self.tracetb_row_preview is not None:
            self.tracetb.remove_row(self.tracetb_row_preview)
            self.tracetb_row_preview = None
        
        if is_upcoming:
            # special: not real, but an upcoming instruction cycle
            self.tracetb_row_preview = self.tracetb.add_row("[underline]next[/underline]", 
                                                            "${:02x}".format(MAH), mah_area, "${:02x}".format(CBA), "${:04x}".format(CA), 
                                                            "${:02x}".format(CD), ctr, sta, "[yellow]"+disinst+"[/yellow]")
            return self.tracetb_row_preview
        else:
            # normal cycle
            return self.tracetb.add_row(cycle_nr, "${:02x}".format(MAH), mah_area, "${:02x}".format(CBA), "${:04x}".format(CA), 
                             "${:02x}".format(CD), ctr, sta, "[green]"+disinst+"[/green]")

        


if __name__ == "__main__":
    app = DebuggerApp()
    app.icd = ICD(x65ftdi.X65Ftdi())
    # which CPU is installed in the target?
    app.is_cputype02 = app.icd.is_cputype02()

    # // deactivate the reset, STOP the cpu
    # app.icd.cpu_ctrl(False, False, False, 
    #             force_irq=False, force_nmi=False, force_abort=False,
    #             block_irq=False, block_nmi=False, block_abort=False)

    app.run()
