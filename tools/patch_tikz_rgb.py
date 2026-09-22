#!/usr/bin/env python3
"""
Add RGB colour support to Dataplot's TikZ LaTeX driver.

Background
----------
Dataplot carries RGB colours to device drivers through GRSEC2 (dp38.F90),
the RGB counterpart to GRSECO. GRSEC2's LaTeX branch (label 15000) is an
empty stub, so RGB colours never reach the LaTeX driver and every TikZ
element falls back to whatever 4-character palette name GRSECO last set --
in practice BLAC.

Approach
--------
The seven places where the TikZ driver writes a colour token do not all have
the RGB arguments in scope (GRDRLI, for instance, receives only ICOL and
JCOL). Rather than change six subroutine signatures, this patch keeps a
single "current TikZ colour token" in a small accessor routine:

  GRTKCN(IMODE, ICNAME, NCNAME)   IMODE=1 set, IMODE=2 get

  * GRSECO's LaTeX branch stores the 4-character palette name.
  * GRSEC2's LaTeX branch generates a name (DPC1, DPC2, ...), writes
    \definecolor{DPCn}{RGB}{r,g,b} immediately, and stores that name.
  * All seven emitters read the token instead of using ICOL directly.

\definecolor is valid inside a tikzpicture and the definition is written
immediately before the command that uses it, so no preamble bookkeeping and
no group-scope problems.

Usage:  patch_tikz_rgb.py <path to dataplot src directory>
"""

import re
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
PATH = f"{SRC}/dp38.F90"

with open(PATH) as fh:
    text = fh.read()

if "GRTKCN" in text:
    print("already patched")
    sys.exit(0)

applied = []


def fail(msg):
    sys.stderr.write(f"ERROR: {msg}\n")
    sys.exit(1)


# ---------------------------------------------------------------------
# 1. The accessor routine plus the \definecolor writer.
# ---------------------------------------------------------------------

NEW_ROUTINES = r"""
      SUBROUTINE GRTKCN(IMODE,ICNAME,NCNAME)
!
!     PURPOSE--HOLD THE CURRENT COLOR TOKEN FOR THE TIKZ LATEX DRIVER.
!              IMODE=1 STORES A TOKEN, IMODE=2 RETURNS THE STORED TOKEN.
!
!              THE TIKZ DRIVER WRITES A COLOR TOKEN IN SEVEN PLACES, AND
!              NOT ALL OF THE ROUTINES INVOLVED RECEIVE THE RGB
!              ARGUMENTS (GRDRLI RECEIVES ONLY ICOL AND JCOL).  KEEPING
!              THE TOKEN HERE LETS GRSECO AND GRSEC2 SET IT AND LETS ALL
!              SEVEN EMITTERS READ IT WITHOUT CHANGING ANY SIGNATURES.
!
!     LANGUAGE--ANSI FORTRAN (1977)
!
!-----------------------------------------------------------------------
!
      CHARACTER*8 ICNAME
      CHARACTER*8 ISAVED
      INTEGER IMODE,NCNAME,NSAVED
      SAVE ISAVED,NSAVED
      DATA ISAVED/'BLAC    '/
      DATA NSAVED/4/
!
      IF(IMODE.EQ.1)THEN
        ISAVED=ICNAME
        NSAVED=NCNAME
        IF(NSAVED.LT.1)NSAVED=1
        IF(NSAVED.GT.8)NSAVED=8
      ELSE
        ICNAME=ISAVED
        NCNAME=NSAVED
      ENDIF
!
      RETURN
      END SUBROUTINE GRTKCN
      SUBROUTINE GRTKRG(IRED2,IGREE2,IBLUE2)
!
!     PURPOSE--FOR THE TIKZ LATEX DRIVER, WRITE A \definecolor LINE FOR
!              AN ARBITRARY RGB TRIPLET AND MAKE THE GENERATED NAME THE
!              CURRENT COLOR TOKEN.
!
!              \definecolor IS VALID INSIDE A tikzpicture ENVIRONMENT AND
!              IS WRITTEN IMMEDIATELY BEFORE THE COMMAND THAT USES IT.
!
!     LANGUAGE--ANSI FORTRAN (1977)
!
!-----------------------------------------------------------------------
!
      CHARACTER*4 ISUBN0
      CHARACTER*130 ICSTR
      CHARACTER*8 ICNAME
      CHARACTER*8 INUMBR
      INTEGER IRED2,IGREE2,IBLUE2
      INTEGER ICOUNT,NCSTR,NCNAME,I1,I2,I3,J
      SAVE ICOUNT
      DATA ICOUNT/0/
!
      ISUBN0='TKRG'
!
      I1=IRED2
      I2=IGREE2
      I3=IBLUE2
      IF(I1.LT.0)I1=0
      IF(I1.GT.255)I1=255
      IF(I2.LT.0)I2=0
      IF(I2.GT.255)I2=255
      IF(I3.LT.0)I3=0
      IF(I3.GT.255)I3=255
!
      ICOUNT=ICOUNT+1
      IF(ICOUNT.GT.99999)ICOUNT=1
      WRITE(INUMBR,'(I8)')ICOUNT
      ICNAME='DPC'
      NCNAME=3
      DO J=1,8
        IF(INUMBR(J:J).NE.' ')THEN
          NCNAME=NCNAME+1
          ICNAME(NCNAME:NCNAME)=INUMBR(J:J)
        ENDIF
      ENDDO
!
      ICSTR=' '
      ICSTR(1:13)='\definecolor{'
      NCSTR=13
      ICSTR(NCSTR+1:NCSTR+NCNAME)=ICNAME(1:NCNAME)
      NCSTR=NCSTR+NCNAME
      ICSTR(NCSTR+1:NCSTR+7)='}{RGB}{'
      NCSTR=NCSTR+7
!
      WRITE(INUMBR,'(I8)')I1
      DO J=1,8
        IF(INUMBR(J:J).NE.' ')THEN
          NCSTR=NCSTR+1
          ICSTR(NCSTR:NCSTR)=INUMBR(J:J)
        ENDIF
      ENDDO
      NCSTR=NCSTR+1
      ICSTR(NCSTR:NCSTR)=','
      WRITE(INUMBR,'(I8)')I2
      DO J=1,8
        IF(INUMBR(J:J).NE.' ')THEN
          NCSTR=NCSTR+1
          ICSTR(NCSTR:NCSTR)=INUMBR(J:J)
        ENDIF
      ENDDO
      NCSTR=NCSTR+1
      ICSTR(NCSTR:NCSTR)=','
      WRITE(INUMBR,'(I8)')I3
      DO J=1,8
        IF(INUMBR(J:J).NE.' ')THEN
          NCSTR=NCSTR+1
          ICSTR(NCSTR:NCSTR)=INUMBR(J:J)
        ENDIF
      ENDDO
      NCSTR=NCSTR+1
      ICSTR(NCSTR:NCSTR)='}'
!
      CALL GRWRST(ICSTR,NCSTR,ISUBN0)
      CALL GRTKCN(1,ICNAME,NCNAME)
!
      RETURN
      END SUBROUTINE GRTKRG
"""

# Append after GRSEC2 ends.
anchor = "      END SUBROUTINE GRSEC2\n"
if anchor not in text:
    fail("cannot find END SUBROUTINE GRSEC2")
text = text.replace(anchor, anchor + NEW_ROUTINES, 1)
applied.append("added GRTKCN and GRTKRG")


# ---------------------------------------------------------------------
# 2. GRSECO LaTeX branch: record the palette name as the current token.
# ---------------------------------------------------------------------

old_seco = """15000 CONTINUE
      IF(ILATCO.EQ.'ON')THEN
        IF(JCOL.GE.1000 .AND. JCOL.LE.1999)ICOL='RED'
        IF(JCOL.GE.2000 .AND. JCOL.LE.2999)ICOL='GREE'
        IF(JCOL.GE.3000 .AND. JCOL.LE.3999)ICOL='BLUE'
"""
new_seco = """15000 CONTINUE
      IF(ILATCO.EQ.'ON')THEN
        IF(JCOL.GE.1000 .AND. JCOL.LE.1999)ICOL='RED'
        IF(JCOL.GE.2000 .AND. JCOL.LE.2999)ICOL='GREE'
        IF(JCOL.GE.3000 .AND. JCOL.LE.3999)ICOL='BLUE'
      ENDIF
!
!     RECORD THE NAMED COLOR AS THE CURRENT TIKZ COLOR TOKEN.  THIS IS
!     DONE WHETHER OR NOT COLOR IS ON SO THAT THE TOKEN CAN NEVER GO
!     STALE.
!
      ITKCNM=ICOL
      NTKCNM=4
      DO ITKJJ=4,1,-1
        IF(ICOL(ITKJJ:ITKJJ).NE.' ')THEN
          NTKCNM=ITKJJ
          EXIT
        ENDIF
      ENDDO
      CALL GRTKCN(1,ITKCNM,NTKCNM)
!
      IF(ILATCO.EQ.'ON')THEN
"""
if old_seco not in text:
    fail("cannot find GRSECO LaTeX branch")
text = text.replace(old_seco, new_seco, 1)
applied.append("GRSECO stores the named colour token")


# ---------------------------------------------------------------------
# 3. GRSEC2 LaTeX branch: the stub that made RGB unreachable.
# ---------------------------------------------------------------------

old_sec2 = """!               **  TREAT THE LATEX (USING EEPIC)    DRIVER         **
!               ******************************************************
!
15000 CONTINUE
      GO TO 9000
!
!               ******************************************************
!               **  STEP 160--                                      **
!               **  TREAT THE SCALABLE VECTOR GRAPHICS       DRIVER **"""
new_sec2 = """!               **  TREAT THE LATEX (USING EEPIC)    DRIVER         **
!               ******************************************************
!
15000 CONTINUE
!
!     2026: THE TIKZ DRIVER CAN EXPRESS AN ARBITRARY RGB COLOR BY
!           WRITING A \\definecolor LINE AND REFERENCING THE GENERATED
!           NAME.  THE EPIC/EEPIC DRIVER HAS NO EQUIVALENT, SO IT IS
!           LEFT WITH THE NAMED-COLOR BEHAVIOR.
!
!           NOTE THAT THE ARGUMENT ORDER OF THIS ROUTINE IS
!           (ARED,ABLUE,AGREEN) RATHER THAN (ARED,AGREEN,ABLUE).
!
!           GRTRC2 RETURNS RAW VALUES IN THE RANGE 0 TO IRGBMX (255 BY
!           DEFAULT), NOT NORMALIZED VALUES.  EACH DEVICE BRANCH SCALES
!           THEM AS IT NEEDS, SO SCALE TO 0-255 FOR \definecolor{}{RGB}.
!
      IF(ILATDR.EQ.'TIKZ' .AND. IRGBFL.EQ.1)THEN
        ATKMAX=REAL(IRGBMX)
        IF(ATKMAX.LE.0.0)ATKMAX=255.0
        ITKRED=INT(ARED*255.0/ATKMAX + 0.5)
        ITKGRE=INT(AGREEN*255.0/ATKMAX + 0.5)
        ITKBLU=INT(ABLUE*255.0/ATKMAX + 0.5)
        CALL GRTKRG(ITKRED,ITKGRE,ITKBLU)
      ENDIF
      GO TO 9000
!
!               ******************************************************
!               **  STEP 160--                                      **
!               **  TREAT THE SCALABLE VECTOR GRAPHICS       DRIVER **"""
if old_sec2 not in text:
    fail("cannot find GRSEC2 LaTeX stub")
text = text.replace(old_sec2, new_sec2, 1)
applied.append("GRSEC2 LaTeX stub now emits \\definecolor for RGB")


# ---------------------------------------------------------------------
# 3b. GRTRC2 is the capability gate: it hardcodes IRGBFL=0 for the LaTeX
#     device, so callers never reach GRSEC2 at all. TikZ can express RGB;
#     epic/eepic cannot, so the flag is set per driver.
# ---------------------------------------------------------------------

old_trc2 = """15000 CONTINUE
      IRGBFL=0
      GO TO 9000
!
!               ******************************************************
!               **  STEP 160--                                      **
!               **  TREAT THE SVG (SCALABLE VECTOR GRAPHICS) DRIVER **"""
new_trc2 = """15000 CONTINUE
!
!     2026: THE TIKZ DRIVER CAN EXPRESS AN ARBITRARY RGB COLOR VIA
!           \\definecolor.  THE EPIC/EEPIC DRIVER CANNOT, SO IT KEEPS
!           THE NAMED-COLOR MODEL.
!
      IF(ILATDR.EQ.'TIKZ')THEN
        IRGBFL=1
      ELSE
        IRGBFL=0
      ENDIF
      GO TO 9000
!
!               ******************************************************
!               **  STEP 160--                                      **
!               **  TREAT THE SVG (SCALABLE VECTOR GRAPHICS) DRIVER **"""
if old_trc2 not in text:
    fail("cannot find GRTRC2 LaTeX capability stanza")
text = text.replace(old_trc2, new_trc2, 1)
applied.append("GRTRC2 reports RGB support for the TikZ driver")


# ---------------------------------------------------------------------
# 4. The seven emitters read the token instead of ICOL.
# ---------------------------------------------------------------------

pattern = re.compile(
    r"^([ \t]+)ICSTR\(NCSTR\+1:NCSTR\+NCCOLO\)=ICOL\(1:NCCOLO\)\n"
    r"([ \t]+)NCSTR=NCSTR\+NCCOLO\n",
    re.M,
)


def emitter(m):
    ind, ind2 = m.group(1), m.group(2)
    return (
        f"{ind}CALL GRTKCN(2,ITKCNM,NCCOLO)\n"
        f"{ind}ICSTR(NCSTR+1:NCSTR+NCCOLO)=ITKCNM(1:NCCOLO)\n"
        f"{ind2}NCSTR=NCSTR+NCCOLO\n"
    )


text, n = pattern.subn(emitter, text)
if n != 7:
    fail(f"expected 7 colour-token sites, patched {n}")
applied.append(f"{n} emitters read the current token")


# ---------------------------------------------------------------------
# 5. Declarations in the routines that now reference ITKCNM / NTKCNM.
# ---------------------------------------------------------------------

DECL_ROUTINES = ["GRDRLI", "GRDRPH", "GRDRPL", "GRFIRE", "GRWRTH", "GRWRTV",
                 "GRSECO"]
lines = text.split("\n")
current = None
inserted = 0
out = []
done = set()
for ln in lines:
    m = re.match(r"^      SUBROUTINE ([A-Z0-9_]+)", ln)
    if m:
        current = m.group(1)
    out.append(ln)
    if (current in DECL_ROUTINES and current not in done
            and ln.strip() == "CHARACTER*4 ICOL"):
        indent = ln[:len(ln) - len(ln.lstrip())]
        out.append(f"{indent}CHARACTER*8 ITKCNM")
        out.append(f"{indent}INTEGER NTKCNM")
        out.append(f"{indent}INTEGER ITKJJ")
        done.add(current)
        inserted += 1
text = "\n".join(out)
missing = set(DECL_ROUTINES) - done
if missing:
    fail(f"could not add declarations to: {sorted(missing)}")
applied.append(f"declarations added to {inserted} routines")

# GRSEC2 needs its own integers. Insert after its CHARACTER*130 ICSTR line,
# located by scanning forward from the SUBROUTINE statement (the declaration
# block is broken up by comment lines, so a literal block match is brittle).
lines = text.split("\n")
start = None
for i, ln in enumerate(lines):
    if ln.startswith("      SUBROUTINE GRSEC2"):
        start = i
        break
if start is None:
    fail("cannot find SUBROUTINE GRSEC2")
placed = False
for i in range(start, min(start + 200, len(lines))):
    if lines[i].strip() == "CHARACTER*130 ICSTR":
        lines.insert(i + 1, "      INTEGER ITKRED,ITKGRE,ITKBLU\n      REAL ATKMAX")
        placed = True
        break
if not placed:
    fail("cannot find GRSEC2 CHARACTER*130 ICSTR declaration")
text = "\n".join(lines)
applied.append("GRSEC2 declarations added")

with open(PATH, "w") as fh:
    fh.write(text)

for a in applied:
    print("  " + a)
print("patched " + PATH)
