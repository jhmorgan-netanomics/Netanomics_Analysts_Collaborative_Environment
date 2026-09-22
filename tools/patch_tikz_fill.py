#!/usr/bin/env python3
r"""
Fix TikZ fill output in Dataplot's LaTeX driver.

Background
----------
Dataplot fills a region in one of three ways (see the comment at the top of
GRFIRE in dp38.F90): a box, a solid simple polygon (software fill in GRFIR2),
or a general polygon (software fill in GRFIR3). The August 2026 TikZ driver
does a hardware fill for the first case only -- a solid BOX becomes
\fill[...] rectangle. Every other solid fill (REGION FILL, CHARACTER FILL,
polygons) falls through to GRFIR2, which draws it as hundreds of short
vertical scanlines through GRDRLI.

GRDRLI's TikZ branch writes the second endpoint of each segment wrongly:

  * the field width passed to GRTRIN is computed for IX1 and IY1 but not
    recomputed for IX2 and IY2, so the second endpoint reuses IY1's width.
    GRTRIN writes asterisks when a number is wider than its field, and pads
    with blanks when it is narrower:

        \draw[GRAY](113pt,83pt) -- (**pt,52);      IY1 has 2 digits, IX2 has 3
        \draw[GRAY](119pt,100pt) -- (119pt, 52);   IY1 has 3 digits, IY2 has 2

  * the closing token is ');' where it should be 'pt);', so the second y has
    no unit. A bare number in a TikZ coordinate is a multiple of the unit
    vector (1cm), so "52" is 52cm.

The asterisks abort pdflatex ("Fatal error occurred, no output PDF file
produced"); the missing unit silently inflates the picture to thousands of
points tall. The same width logic has two latent cases: a negative value
(IX.GT.9 is false, so the width is 1 and "-16" becomes "*"), and a value
above 999.

What this patch does
--------------------
  1. Adds GRTKNC(IX,NCH): the exact number of characters GRTRIN needs for
     IX, sign included.
  2. GRDRLI: computes the width for all four coordinates with GRTKNC and
     closes the segment with 'pt);'. This is the bug fix proper; it repairs
     every software fill and any other caller of GRDRLI.
  3. GRFIRE: adds a TikZ hardware fill for solid non-box regions, written as
     one closed path

        \fill[GRAY] (113pt,52pt) -- (113pt,204pt) -- ... -- cycle;

     alongside the existing BOX -> rectangle case. This is the improvement:
     a solid fill instead of scanlines, and a much smaller file. The path
     may span several output lines; TikZ reads to the semicolon.

Step 2 alone makes the output correct. Step 3 is what makes it look right.

If patch_tikz_rgb.py has already been applied (GRTKCN present), the new
\fill emitter reads the current colour token the same way the other seven
emitters do. Apply this patch AFTER patch_tikz_rgb.py: the RGB patch expects
exactly seven colour-token sites and will stop if it finds eight.

Usage:  patch_tikz_fill.py <path to dataplot src directory>

Exit status: 0 patched (or already patched), 2 target code not found (file
left untouched), 1 any other failure.
"""

import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
PATH = f"{SRC}/dp38.F90"

with open(PATH) as fh:
    text = fh.read()

if "GRTKNC" in text:
    print("already patched")
    sys.exit(0)

applied = []
HAVE_RGB = "GRTKCN" in text


def fail(msg, code=1):
    sys.stderr.write(f"ERROR: {msg}\n")
    sys.exit(code)


def replace_once(old, new, what):
    # Nothing is written until every edit has matched, so a failure here
    # leaves dp38.F90 untouched.  Exit status 2 means "the code this patch
    # targets is not there" -- most likely fixed or rewritten upstream.
    global text
    n = text.count(old)
    if n == 0:
        fail(f"{what}: target code not found (changed upstream?)", 2)
    if n > 1:
        fail(f"{what}: expected 1 match, found {n}")
    text = text.replace(old, new, 1)
    applied.append(what)


# ---------------------------------------------------------------------
# 1. Field-width helper, appended after GRDRLI.
# ---------------------------------------------------------------------

NEW_ROUTINE = """      SUBROUTINE GRTKNC(IX,NCH)
!
!     PURPOSE--FOR THE TIKZ LATEX DRIVER, RETURN IN NCH THE NUMBER OF
!              CHARACTERS NEEDED TO WRITE THE INTEGER IX, INCLUDING A
!              LEADING MINUS SIGN.  THIS IS THE FIELD WIDTH TO PASS TO
!              GRTRIN, WHICH WRITES ASTERISKS IF THE FIELD IS TOO NARROW
!              AND PADS WITH BLANKS IF IT IS TOO WIDE.
!
!     LANGUAGE--ANSI FORTRAN (1977)
!
!-----------------------------------------------------------------------
!
      INTEGER IX,NCH,IABSX
!
      IABSX=IABS(IX)
      NCH=1
   10 CONTINUE
      IF(IABSX.GE.10)THEN
        IABSX=IABSX/10
        NCH=NCH+1
        GO TO 10
      ENDIF
      IF(IX.LT.0)NCH=NCH+1
!
      RETURN
      END SUBROUTINE GRTKNC
"""

anchor = "      END SUBROUTINE GRDRLI\n"
replace_once(anchor, anchor + NEW_ROUTINE, "added GRTKNC")


# ---------------------------------------------------------------------
# 2. GRDRLI TikZ branch: width for every coordinate, and the missing unit.
# ---------------------------------------------------------------------

old_drli = """        IF(IX1.GT.99)THEN
          NCHTOT=3
        ELSEIF(IX1.GT.9)THEN
          NCHTOT=2
        ELSE
          NCHTOT=1
        ENDIF
        CALL GRTRIN(IX1,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+3)='pt,'
        NCSTR=NCSTR+3
        IF(IY1.GT.99)THEN
          NCHTOT=3
        ELSEIF(IY1.GT.9)THEN
          NCHTOT=2
        ELSE
          NCHTOT=1
        ENDIF
        CALL GRTRIN(IY1,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+8)='pt) -- ('
        NCSTR=NCSTR+8
        CALL GRTRIN(IX2,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+3)='pt,'
        NCSTR=NCSTR+3
        CALL GRTRIN(IY2,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+2)=');'
        NCSTR=NCSTR+2
        CALL GRWRST(ICSTR,NCSTR,ISUBN0)
"""
new_drli = """!
!       2026: THE FIELD WIDTH WAS COMPUTED FOR IX1 AND IY1 ONLY, SO IX2
!             AND IY2 REUSED IY1'S WIDTH (GRTRIN THEN WRITES ASTERISKS OR
!             PADS WITH BLANKS), AND THE SEGMENT WAS CLOSED WITH ');'
!             INSTEAD OF 'pt);', LEAVING THE SECOND Y WITHOUT A UNIT.
!             GRTKNC GIVES THE EXACT WIDTH, SIGN INCLUDED.
!
        CALL GRTKNC(IX1,NCHTOT)
        CALL GRTRIN(IX1,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+3)='pt,'
        NCSTR=NCSTR+3
        CALL GRTKNC(IY1,NCHTOT)
        CALL GRTRIN(IY1,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+8)='pt) -- ('
        NCSTR=NCSTR+8
        CALL GRTKNC(IX2,NCHTOT)
        CALL GRTRIN(IX2,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+3)='pt,'
        NCSTR=NCSTR+3
        CALL GRTKNC(IY2,NCHTOT)
        CALL GRTRIN(IY2,NCHTOT,ICSTR,NCSTR)
        ICSTR(NCSTR+1:NCSTR+4)='pt);'
        NCSTR=NCSTR+4
        CALL GRWRST(ICSTR,NCSTR,ISUBN0)
"""
replace_once(old_drli, new_drli, "GRDRLI writes all four coordinates correctly")


# ---------------------------------------------------------------------
# 3. GRFIRE TikZ branch: hardware fill for solid non-box regions.
# ---------------------------------------------------------------------

if HAVE_RGB:
    colour_lines = """        CALL GRTKCN(2,ITKCNM,NCCOLO)
        ICSTR(NCSTR+1:NCSTR+NCCOLO)=ITKCNM(1:NCCOLO)
        NCSTR=NCSTR+NCCOLO
"""
else:
    colour_lines = """        NCCOLO=4
        DO II=4,1,-1
           IF(ICOL(II:II).NE.' ')THEN
             NCCOLO=II
             EXIT
           ENDIF
        ENDDO
        ICSTR(NCSTR+1:NCSTR+NCCOLO)=ICOL(1:NCCOLO)
        NCSTR=NCSTR+NCCOLO
"""

old_fire = """        ICSTR(NCSTR+1:NCSTR+4)='pt);'
        NCSTR=NCSTR+4
        CALL GRWRST(ICSTR,NCSTR,ISUBN0)
      ELSE
        IFACTO=-999
        GO TO 8900
      ENDIF
"""
new_fire = """        ICSTR(NCSTR+1:NCSTR+4)='pt);'
        NCSTR=NCSTR+4
        CALL GRWRST(ICSTR,NCSTR,ISUBN0)
      ELSEIF(ILATDR.EQ.'TIKZ' .AND. IFIG.NE.'BOX' .AND.                   &
        (IPATT.EQ.'SOLI' .OR. IPATT.EQ.'FILL'))THEN
!
!       2026: HARDWARE FILL FOR A SOLID NON-BOX REGION.  WRITE THE
!             VERTICES AS ONE CLOSED TIKZ PATH INSTEAD OF FALLING
!             THROUGH TO THE SOFTWARE SCANLINE FILL IN GRFIR2.  THE PATH
!             MAY SPAN SEVERAL OUTPUT LINES; TIKZ READS TO THE SEMICOLON.
!             CONSECUTIVE VERTICES THAT ROUND TO THE SAME POINT ARE
!             WRITTEN ONCE.  TIKZ FILLS CONCAVE POLYGONS CORRECTLY, SO
!             NO CONVEXITY TEST IS NEEDED.
!
        IF(NP.LT.3)GO TO 9000
        ICSTR(1:1)=IBASLC
        ICSTR(2:6)='fill['
        NCSTR=6
""" + colour_lines + """        ICSTR(NCSTR+1:NCSTR+1)=']'
        NCSTR=NCSTR+1
        ITKNV=0
        ITKXL=0
        ITKYL=0
        DO ITKI=1,NP
          CALL GRTRSD(PX(ITKI),PY(ITKI),ITKX,ITKY,ISUBN0)
          IF(ITKNV.GT.0 .AND. ITKX.EQ.ITKXL .AND. ITKY.EQ.ITKYL)CYCLE
          IF(NCSTR.GT.90)THEN
            CALL GRWRST(ICSTR,NCSTR,ISUBN0)
            NCSTR=0
          ENDIF
          IF(ITKNV.GT.0)THEN
            ICSTR(NCSTR+1:NCSTR+3)=' --'
            NCSTR=NCSTR+3
          ENDIF
          ICSTR(NCSTR+1:NCSTR+2)=' ('
          NCSTR=NCSTR+2
          CALL GRTKNC(ITKX,NCHTOT)
          CALL GRTRIN(ITKX,NCHTOT,ICSTR,NCSTR)
          ICSTR(NCSTR+1:NCSTR+3)='pt,'
          NCSTR=NCSTR+3
          CALL GRTKNC(ITKY,NCHTOT)
          CALL GRTRIN(ITKY,NCHTOT,ICSTR,NCSTR)
          ICSTR(NCSTR+1:NCSTR+3)='pt)'
          NCSTR=NCSTR+3
          ITKXL=ITKX
          ITKYL=ITKY
          ITKNV=ITKNV+1
        ENDDO
        ICSTR(NCSTR+1:NCSTR+10)=' -- cycle;'
        NCSTR=NCSTR+10
        CALL GRWRST(ICSTR,NCSTR,ISUBN0)
      ELSE
        IFACTO=-999
        GO TO 8900
      ENDIF
"""
replace_once(old_fire, new_fire, "GRFIRE fills solid non-box regions with a TikZ path"
             + (" (RGB colour token)" if HAVE_RGB else ""))

with open(PATH, "w") as fh:
    fh.write(text)

for a in applied:
    print("  " + a)
print("patched " + PATH)
