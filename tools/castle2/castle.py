"""Chronicle Clash Sky Citadel v2 - the castle design (uses kit.py). Run: python3 castle.py -> castle.pkl"""
import math, pickle, random, json
import kit
from kit import *

D = math.radians
ROUTE = []      # walk points for the game's test bot: (kind, data)
LADDERS = []
LANDINGS = []
DEADENDS = []
DOORS = []

# ------------------------------------------------------------------ levels (metres, game coords)
DOCK_Y = 52.0
BASE_Y = 56.0     # base terrace (ring deck 1 starts)
GAL1 = 62.0       # drum A gallery / ring deck 1 top
TER_A = 74.0      # ring deck 2 start
GAL2 = 80.0
TER_B = 92.0      # ring deck 3 start
GAL3 = 104.0
CORE_Y = 105.0
SUMMIT = 119.0
CROWN = 131.0
TOP = 139.0

R_BASE = 41.0
CX, CZ = 0.0, 0.0      # centre of the drums
KX, KZ, KR = 3.0, -12.0, 20.0   # crown ring centre / radius in plan (crown sits toward the back)
EX, EZ = 0.0, 0.0      # the eye (plan)
BODY_WARP = (0.0, 0.0, 0.714, 3.0)   # rounded oval footprint: x 1, z 0.714
RA, RB, RC, RK = 34.5, 30.5, 27.0, 20.0   # drum wall centre radii (A, B, C, crown)
TW = 2.0                                  # wall thickness
EYE_R = 5.5
CORE_R = 13.0

# ------------------------------------------------------------------ underside rock
rock_prof = [(0.25, 0.0), (2.5, 3.0), (5.5, 7.0), (9.0, 12.0), (13.0, 18.0), (17.0, 24.0), (21.5, 30.0),
             (25.5, 36.0), (29.5, 42.0), (33.0, 47.0), (36.5, 50.5), (38.5, 52.6)]
kit.WARP = True
rows = rock_cone(CX, CZ, rock_prof, segs=56, seed=11, amp=2.2)
# hanging rock spikes round the rim and lower
rnd = random.Random(5)
for i in range(26):
    a = TAU * i / 26 + rnd.uniform(-0.08, 0.08)
    r = rnd.uniform(30, 38)
    y = 47 + (r - 30) * 0.6
    x, _, z = polar(CX, CZ, r, a, 0)
    stalactite(x, y, z, rnd.uniform(5, 12), rnd.uniform(1.4, 2.6), seed=i)
for i in range(14):
    a = TAU * i / 14 + 0.2
    r = rnd.uniform(18, 26)
    y = 24 + (r - 18) * 1.2
    x, _, z = polar(CX, CZ, r, a, 0)
    stalactite(x, y, z, rnd.uniform(4, 9), rnd.uniform(1.2, 2.2), seed=100 + i)
# glowing crystal veins: chains of shards down the rock toward the spike
for v, a in enumerate([0.0, 0.9, 1.9, 2.9, 3.8, 4.8, 5.6]):
    for k, (r, y) in enumerate(rock_prof[2:-1]):
        x, _, z = polar(CX, CZ, r + 0.6, a + 0.05 * math.sin(k * 1.7 + v), y)
        crystal_shard(x, y, z, 2.2 + 0.25 * k, 0.45, (math.sin(a) * 0.5, math.cos(a) * 0.5), seed=v * 50 + k)
crystal_down(CX, 3.0, CZ, 6.0, 0.9, seed=77)
crystal_cluster(CX, 1.0, CZ, 3.0, 4, down=True, seed=9)

# ------------------------------------------------------------------ base platform (y 52.5 - 56)
disc('floor', CX, CZ, 0, R_BASE, BASE_Y, segs=112, colmode=True)
lathe('stone', [(R_BASE, 52.6), (R_BASE, BASE_Y - 0.9)], CX, CZ, 112)
cornice(CX, CZ, R_BASE - 1.05, BASE_Y, segs=112, size=1.0)
disc('stone', CX, CZ, 30.0, R_BASE, 52.6, segs=112, up=False)
corbel_ring(CX, CZ, R_BASE - 4.0, 52.6, 0, TAU, step=3.2, depth=1.6, h=2.4)
# rim parapet with gaps for the dock stair and the bastions
parapet(CX, CZ, R_BASE - 0.4, (BASE_Y, BASE_Y), D(-170), D(170), gaps=[(D(-9), D(9)), (D(38), D(52))])

# ------------------------------------------------------------------ dock (start) + grand stair
FRONT = kit.warp(0, R_BASE, BASE_Y)[1]       # base platform front edge after the warp
DZ0 = FRONT + 6.5                    # dock edge (final coords)
with final():
    box('stone', (0, DOCK_Y - 1.6, DZ0 + 6.0), (16, 3.2, 12), colmode=True, top_mat='floor')
    straight_stair((0, DOCK_Y, DZ0 + 0.5), (0, BASE_Y, FRONT + 0.02), 7.0)
    for sx in (-1, 1):
        tower(sx * 7.0, DZ0 + 11.0, 1.4, DOCK_Y - 2, DOCK_Y + 6, spire=4.0)
        stalactite(sx * 5.0, DOCK_Y - 3.2, DZ0 + 6.0, 7, 2.0, seed=200 + sx)
    stalactite(0, DOCK_Y - 3.2, DZ0 + 9.0, 9, 2.6, seed=202)
FIN = []   # route points already in final coords
ROUTE.append(('walkF', (0, DOCK_Y, DZ0 + 6.0)))
ROUTE.append(('walkF', (0, DOCK_Y, DZ0 + 1.0)))
ROUTE.append(('walkF', (0, BASE_Y, FRONT - 1.6)))

# ------------------------------------------------------------------ drum A (56 -> 74), gallery at 62
# lower storey 56-62: blind arcade outside
arcade(CX, CZ, RA, TW, BASE_Y, GAL1, 0, TAU, 24, open_w=0.5, blind=set(range(24)))
# upper storey 62-74: windows, doors at the gallery entrances
bays = 24
def bay_of(deg, n=bays):
    return int((deg % 360) / 360 * n)
doorsA = arcade(CX, CZ, RA, TW, GAL1, TER_A, 0, TAU, bays, open_w=0.5, sill=1.0,
                doors={bay_of(140), bay_of(225)}, blind={bay_of(0)})
DA = sorted(math.degrees(a) for _, a in doorsA)
cornice(CX, CZ, RA + 1.0, GAL1 + 0.0, segs=96, size=0.5)
base_moulding(CX, CZ, RA + 1.0, BASE_Y, segs=96)
# gallery inside drum A: floor at 62, inner wall r 24, ceiling under terrace A
disc('floor', CX, CZ, 26.0, RA - 1.0, GAL1, segs=96, colmode=True)
disc('stone', CX, CZ, 26.0, RA - 1.0, GAL1 - 0.8, segs=96, up=False)
arcade(CX, CZ, 26.0, 2.0, GAL1, TER_A, 0, TAU, 16, open_w=0.45, blind=set(range(16)))
lathe('stone', [(25.0, BASE_Y), (25.0, GAL1)], CX, CZ, 64, flip=True)
# crystals lighting the gallery
for deg in range(150, 230, 20):
    x, _, z = polar(CX, CZ, 27.2, D(deg), 0)
    crystal_shard(x, GAL1, z, 2.4, 0.4, seed=deg)

# ------------------------------------------------------------------ ring deck 1 (56 -> 62)
# base terrace walk: front, round the right to the spiral stair; combat bastion at 45 deg
deck(CX, CZ, R_BASE - 0.2, R_BASE + 5.0, BASE_Y, D(38), D(52), base=52.6)          # bastion
parapet(CX, CZ, R_BASE + 4.6, (BASE_Y, BASE_Y), D(38), D(52))
LANDINGS.append(('ring1 bastion', polar(CX, CZ, RA + 7.5, D(45), BASE_Y)))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.6, D(20), BASE_Y)))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.6, D(62), BASE_Y)))
# spiral stair 56 -> 62 hugging drum A (theta 70 -> 130)
deck(CX, CZ, RA + 1.3, RA + 6.0, BASE_Y, D(70), D(130), y1=GAL1, base=BASE_Y)
parapet(CX, CZ, RA + 5.8, (BASE_Y, GAL1), D(70), D(130))
deck(CX, CZ, RA + 1.0, RA + 6.0, GAL1, D(130), D(146), base=BASE_Y)   # landing at the door
parapet(CX, CZ, RA + 5.8, (GAL1, GAL1), D(130), D(146))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.65, D(72), BASE_Y)))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.65, D(128), GAL1)))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.0, D(DA[0]), GAL1)))
# through the door into the gallery, round inside, out the far door
ROUTE.append(('walk', polar(CX, CZ, RA - 5.5, D(DA[0]), GAL1)))
for deg in (165, 190, 215):
    ROUTE.append(('walk', polar(CX, CZ, RA - 5.5, D(deg), GAL1)))
ROUTE.append(('walk', polar(CX, CZ, RA - 5.5, D(DA[1]), GAL1)))
ROUTE.append(('walk', polar(CX, CZ, RA + 3.0, D(DA[1]), GAL1)))
# outer balcony at 62 (theta 215 -> 282), bastion at 250, dead end past the ladder
deck(CX, CZ, RA + 1.0, RA + 6.5, GAL1, D(215), D(282), base=BASE_Y)
parapet(CX, CZ, RA + 6.3, (GAL1, GAL1), D(215), D(243))
parapet(CX, CZ, RA + 6.3, (GAL1, GAL1), D(257), D(282))
deck(CX, CZ, RA + 6.3, RA + 11.0, GAL1, D(243), D(257), base=BASE_Y)
parapet(CX, CZ, RA + 10.8, (GAL1, GAL1), D(243), D(257))
LANDINGS.append(('ring1 balcony', polar(CX, CZ, RA + 7.0, D(250), GAL1)))
DEADENDS.append(('ring1 balcony end', polar(CX, CZ, RA + 4.0, D(278), GAL1)))
crystal_cluster(*polar(CX, CZ, RA + 5.0, D(280), GAL1), 3.0, 5, seed=31)
# undercroft arcade carrying the raised decks
arcade(CX, CZ, RA + 6.0, 1.0, BASE_Y, GAL1 - 0.8, D(215), D(282), 8, open_w=0.6, colmode=False)
arcade(CX, CZ, RA + 5.5, 1.0, BASE_Y, GAL1 - 0.8, D(130), D(146), 2, open_w=0.6, colmode=False)
# ladder 1: balcony (62) up drum A to terrace A (74) at theta 265
LADDERS.append({'bottom': polar(CX, CZ, RA + 1.9, D(266), GAL1), 'top': polar(CX, CZ, RA - 1.0, D(266), TER_A), 'face': 'in'})
ROUTE.append(('walk', polar(CX, CZ, RA + 4.0, D(240), GAL1)))
ROUTE.append(('walk', polar(CX, CZ, RA + 2.6, D(266), GAL1)))
ROUTE.append(('ladder', 0))

# ------------------------------------------------------------------ terrace A (74) and drum B (74 -> 92)
# terrace ring r 31 -> 38 with a notch for ladder 1
for a0, a1 in ((D(-94), D(262)), (D(270), D(266 + 0))):
    pass
deck(CX, CZ, RB + 1.0, RA + 4.0, TER_A, D(-90), D(262))
deck(CX, CZ, RB + 1.0, RA - 0.6, TER_A, D(262), D(270))
corbel_ring(CX, CZ, RA + 1.0, TER_A - 0.8, D(-90), D(262), step=2.6, depth=2.8, h=2.2)
parapet(CX, CZ, RA + 3.8, (TER_A, TER_A), D(-90), D(262), gaps=[(D(308), D(322))])
cornice(CX, CZ, RA + 4.0 - 1.0, TER_A - 0.8, segs=96, size=0.8)
arcade(CX, CZ, RB, TW, TER_A, GAL2, 0, TAU, 20, open_w=0.5, blind=set(range(20)))
bb = 20
doorsB = arcade(CX, CZ, RB, TW, GAL2, TER_B, 0, TAU, bb, open_w=0.5, sill=1.0,
                doors={bay_of(90, bb), bay_of(170, bb)}, blind={bay_of(0, bb)})
DB = sorted(math.degrees(a) for _, a in doorsB)
cornice(CX, CZ, RB + 1.0, GAL2, segs=96, size=0.5)
disc('floor', CX, CZ, 22.0, RB - 1.0, GAL2, segs=96, colmode=True)
disc('stone', CX, CZ, 22.0, RB - 1.0, GAL2 - 0.8, segs=96, up=False)
arcade(CX, CZ, 22.0, 2.0, GAL2, TER_B, 0, TAU, 14, open_w=0.45, blind=set(range(14)))
# ceiling of the drum A gallery = underside of terrace A
disc('stone', CX, CZ, 23.0, RA + 1.0, TER_A - 0.8, segs=96, up=False)
disc('stone', CX, CZ, 0.0, 23.0, TER_A - 0.8, segs=64, up=True)
for deg in range(95, 175, 20):
    x, _, z = polar(CX, CZ, 23.2, D(deg), 0)
    crystal_shard(x, GAL2, z, 2.2, 0.38, seed=deg + 1)

# ------------------------------------------------------------------ ring deck 2 (74 -> 80)
ROUTE.append(('walk', polar(CX, CZ, RB + 4.0, D(280), TER_A)))
ROUTE.append(('walk', polar(CX, CZ, RB + 4.0, D(315), TER_A)))
deck(CX, CZ, RA + 3.6, RA + 8.5, TER_A, D(308), D(322), base=TER_A - 3.0)     # bastion
parapet(CX, CZ, RA + 8.3, (TER_A, TER_A), D(308), D(322))
LANDINGS.append(('ring2 bastion', polar(CX, CZ, RA + 6.0, D(315), TER_A)))
ROUTE.append(('walk', polar(CX, CZ, RB + 4.0, D(350), TER_A)))
ROUTE.append(('walk', polar(CX, CZ, RB + 3.5, D(380), TER_A)))
# spiral stair 74 -> 80 hugging drum B (theta 20 -> 80)
deck(CX, CZ, RB + 1.3, RB + 6.0, TER_A, D(20), D(80), y1=GAL2, base=TER_A)
parapet(CX, CZ, RB + 5.8, (TER_A, GAL2), D(20), D(80))
deck(CX, CZ, RB + 1.0, RB + 6.0, GAL2, D(80), D(106), base=TER_A)
parapet(CX, CZ, RB + 5.8, (GAL2, GAL2), D(80), D(106))
arcade(CX, CZ, RB + 5.5, 1.0, TER_A, GAL2 - 0.8, D(80), D(106), 2, open_w=0.6, colmode=False)
ROUTE.append(('walk', polar(CX, CZ, RB + 3.65, D(22), TER_A)))
ROUTE.append(('walk', polar(CX, CZ, RB + 3.65, D(78), GAL2)))
ROUTE.append(('walk', polar(CX, CZ, RB + 3.0, D(DB[0]), GAL2)))
ROUTE.append(('walk', polar(CX, CZ, RB - 6.25, D(DB[0]), GAL2)))
for deg in (115, 140, 160):
    ROUTE.append(('walk', polar(CX, CZ, RB - 6.25, D(deg), GAL2)))
ROUTE.append(('walk', polar(CX, CZ, RB - 6.25, D(DB[1]), GAL2)))
ROUTE.append(('walk', polar(CX, CZ, RB + 3.0, D(DB[1]), GAL2)))
# balcony at 80 (160 -> 228), bastion at 195, dead end
deck(CX, CZ, RB + 1.0, RB + 6.5, GAL2, D(160), D(228), base=TER_A)
parapet(CX, CZ, RB + 6.3, (GAL2, GAL2), D(160), D(188))
parapet(CX, CZ, RB + 6.3, (GAL2, GAL2), D(202), D(228))
deck(CX, CZ, RB + 6.3, RB + 10.5, GAL2, D(188), D(202), base=TER_A)
parapet(CX, CZ, RB + 10.3, (GAL2, GAL2), D(188), D(202))
arcade(CX, CZ, RB + 6.0, 1.0, TER_A, GAL2 - 0.8, D(160), D(228), 7, open_w=0.6, colmode=False)
LANDINGS.append(('ring2 balcony', polar(CX, CZ, RB + 7.0, D(195), GAL2)))
DEADENDS.append(('ring2 balcony end', polar(CX, CZ, RB + 4.0, D(225), GAL2)))
crystal_cluster(*polar(CX, CZ, RB + 5.0, D(226), GAL2), 2.6, 5, seed=32)
LADDERS.append({'bottom': polar(CX, CZ, RB + 1.9, D(212), GAL2), 'top': polar(CX, CZ, RB - 1.0, D(212), TER_B), 'face': 'in'})
ROUTE.append(('walk', polar(CX, CZ, RB + 4.0, D(195), GAL2)))
ROUTE.append(('walk', polar(CX, CZ, RB + 2.6, D(212), GAL2)))
ROUTE.append(('ladder', 1))

# ------------------------------------------------------------------ terrace B (92) and drum C (92 -> 119)
deck(CX, CZ, RC + 1.0, RB + 4.0, TER_B, D(216), D(208 + 360))
deck(CX, CZ, RC + 1.0, RB - 0.6, TER_B, D(208), D(216))
corbel_ring(CX, CZ, RB + 1.0, TER_B - 0.8, D(216), D(568), step=2.6, depth=2.8, h=2.2)
parapet(CX, CZ, RB + 3.8, (TER_B, TER_B), D(216), D(568), gaps=[(D(248), D(262))])
cornice(CX, CZ, RB + 3.0, TER_B - 0.8, segs=96, size=0.8)
arcade(CX, CZ, RC, TW, TER_B, GAL3, 0, TAU, 18, open_w=0.5, blind=set(range(18)))
bc = 18
doorsC = arcade(CX, CZ, RC, TW, GAL3, SUMMIT, 0, TAU, bc, open_w=0.5, sill=1.0,
                doors={bay_of(30, bc), bay_of(115, bc)}, blind={bay_of(0, bc)})
DC = sorted(math.degrees(a) for _, a in doorsC)
print('doors', DA, DB, DC)
cornice(CX, CZ, RC + 1.0, GAL3, segs=96, size=0.5)
disc('floor', CX, CZ, 17.0, RC - 1.0, GAL3, segs=96, colmode=True)
disc('stone', CX, CZ, 17.0, RC - 1.0, GAL3 - 0.8, segs=96, up=False)
disc('stone', CX, CZ, 19.0, RB + 1.0, TER_B - 0.8, segs=96, up=False)
disc('stone', CX, CZ, 0.0, 19.0, TER_B - 0.8, segs=64)
for deg in range(40, 115, 20):
    x, _, z = polar(CX, CZ, 18.2, D(deg), 0)
    crystal_shard(x, GAL3, z, 2.2, 0.38, seed=deg + 2)

# ------------------------------------------------------------------ ring deck 3 (92 -> 104)
ROUTE.append(('walk', polar(CX, CZ, RC + 3.5, D(225), TER_B)))
deck(CX, CZ, RB + 3.6, RB + 8.5, TER_B, D(248), D(262), base=TER_B - 3.0)
parapet(CX, CZ, RB + 8.3, (TER_B, TER_B), D(248), D(262))
LANDINGS.append(('ring3 bastion', polar(CX, CZ, RB + 6.0, D(255), TER_B)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.5, D(255), TER_B)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.5, D(290), TER_B)))
# spiral stair 92 -> 104 hugging drum C (theta 300 -> 380)
deck(CX, CZ, RC + 1.3, RC + 6.0, TER_B, D(300), D(380), y1=GAL3, base=TER_B)
parapet(CX, CZ, RC + 5.8, (TER_B, GAL3), D(300), D(380))
deck(CX, CZ, RC + 1.0, RC + 6.0, GAL3, D(380), D(397), base=TER_B)
parapet(CX, CZ, RC + 5.8, (GAL3, GAL3), D(380), D(397))
arcade(CX, CZ, RC + 5.5, 1.0, TER_B, GAL3 - 0.8, D(380), D(397), 2, open_w=0.6, colmode=False)
ROUTE.append(('walk', polar(CX, CZ, RC + 3.65, D(302), TER_B)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.65, D(378), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.0, D(DC[0] + 360), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC - 7.0, D(DC[0] + 360), GAL3)))
for deg in (55, 80, 100):
    ROUTE.append(('walk', polar(CX, CZ, RC - 7.0, D(deg), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC - 7.0, D(DC[1]), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.0, D(DC[1]), GAL3)))
# balcony at 104 (105 -> 152), bastion 135
deck(CX, CZ, RC + 1.0, RC + 6.5, GAL3, D(105), D(152), base=TER_B)
parapet(CX, CZ, RC + 6.3, (GAL3, GAL3), D(105), D(128))
parapet(CX, CZ, RC + 6.3, (GAL3, GAL3), D(142), D(152))
deck(CX, CZ, RC + 6.3, RC + 10.5, GAL3, D(128), D(142), base=TER_B)
parapet(CX, CZ, RC + 10.3, (GAL3, GAL3), D(128), D(142))
arcade(CX, CZ, RC + 6.0, 1.0, TER_B, GAL3 - 0.8, D(105), D(152), 5, open_w=0.6, colmode=False)
LANDINGS.append(('ring3 balcony', polar(CX, CZ, RC + 7.0, D(135), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC + 5.0, D(135), GAL3)))
# stair 104 -> 119 hugging drum C (theta 152 -> 228) up to the summit terrace
deck(CX, CZ, RC + 1.3, RC + 6.0, GAL3, D(152), D(228), y1=SUMMIT, base=TER_B)
parapet(CX, CZ, RC + 5.8, (GAL3, SUMMIT), D(152), D(228))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.65, D(154), GAL3)))
ROUTE.append(('walk', polar(CX, CZ, RC + 3.65, D(226), SUMMIT)))

# ------------------------------------------------------------------ summit terrace (119), core chamber, crown
# summit floor = top of drum C (and the core chamber's ceiling), eye hole in the middle
disc_hole('floor', CX, CZ, RC + 1.0, EX, EZ, EYE_R, SUMMIT, segs=112, colmode=True)
# the outer summit terrace leaves the summit stair (theta 152 -> 228) open to the sky
deck(CX, CZ, RC + 1.0, RC + 6.0, SUMMIT, D(228), D(152 + 360))
corbel_ring(CX, CZ, RC + 1.0, SUMMIT - 0.8, D(230), D(150 + 360), step=2.6, depth=2.6, h=2.0)
parapet(CX, CZ, RC + 5.8, (SUMMIT, SUMMIT), D(234), D(214 + 360))
cornice(CX, CZ, RC + 5.0, SUMMIT - 0.8, a0=D(228), a1=D(512), segs=96, size=0.8)
# core chamber: floor 105, wall r 13-15 up to 119, ceiling = summit floor, open eye above the centre
disc('floor', CX, CZ, 0, CORE_R + 1.0, CORE_Y, segs=72, colmode=True)
disc('stone', CX, CZ, 0, CORE_R + 1.0, CORE_Y - 1.0, segs=72, up=False)
arcade(CX, CZ, CORE_R + 1.0, 2.0, CORE_Y, SUMMIT - 0.8, 0, TAU, 12, open_w=0.5, blind=set(range(12)), relief='in')
# arena floor: gold rings and a crystal sigil
for rr in (4.0, 8.5, 12.2):
    disc('gold', CX, CZ, rr, rr + 0.35, CORE_Y + 0.02, segs=72)
for k in range(8):
    a = TAU * k / 8
    x0, _, z0 = polar(CX, CZ, 4.35, a, 0); x1, _, z1 = polar(CX, CZ, 8.5, a, 0)
    poly('gold', [(x0 - 0.15 * math.cos(a), CORE_Y + 0.02, z0 + 0.15 * math.sin(a)), (x0 + 0.15 * math.cos(a), CORE_Y + 0.02, z0 - 0.15 * math.sin(a)), (x1 + 0.15 * math.cos(a), CORE_Y + 0.02, z1 - 0.15 * math.sin(a)), (x1 - 0.15 * math.cos(a), CORE_Y + 0.02, z1 + 0.15 * math.sin(a))][::-1])
disc_hole('stone', CX, CZ, CORE_R + 2.0, EX, EZ, EYE_R, SUMMIT - 0.8, segs=72, up=False, colmode=True)
for k in range(8):
    a = TAU * k / 8 + 0.2
    x, _, z = polar(CX, CZ, CORE_R - 0.9, a, 0)
    crystal_cluster(x, CORE_Y, z, 3.4, 4, seed=60 + k)
    x, _, z = polar(CX, CZ, CORE_R - 0.4, a + 0.39, 0)
    crystal_down(x, SUMMIT - 0.8, z, 2.6, 0.5, seed=80 + k)
crystal_cluster(CX, CORE_Y, CZ - 9.0, 2.6, 3, seed=99)
LANDINGS.append(('core arena', (CX, CORE_Y, CZ)))
# crown ring (centre KX, KZ, toward the back like the guides), windows all round
arcade(KX, KZ, KR, TW, SUMMIT, CROWN, 0, TAU, 14, open_w=0.45, sill=2.0)
base_moulding(KX, KZ, KR + 1.0, SUMMIT, segs=80)
# crown stair 119 -> 131 hugging the crown ring (theta_k 252 -> 338)
ROUTE.append(('walk', polar(KX, KZ, 22.0, D(268), SUMMIT)))
deck(KX, KZ, KR + 1.3, KR + 6.0, SUMMIT, D(268), D(350), y1=CROWN, base=SUMMIT)
parapet(KX, KZ, KR + 5.8, (SUMMIT, CROWN), D(268), D(350))
deck(KX, KZ, KR - 1.0, KR + 6.0, CROWN, D(350), D(366))
parapet(KX, KZ, KR + 5.8, (CROWN, CROWN), D(350), D(366))
ROUTE.append(('walk', polar(KX, KZ, 22.0, D(271), SUMMIT)))
ROUTE.append(('walk', polar(KX, KZ, 22.0, D(348), CROWN)))
ROUTE.append(('walk', polar(KX, KZ, 17.0, D(358), CROWN)))
# crown walkway (131) = roof of the crown hall, the eye opens through it
disc_hole('floor', KX, KZ, KR + 1.0, EX, EZ, EYE_R, CROWN, segs=96, colmode=True)
disc_hole('stone', KX, KZ, KR + 1.0, EX, EZ, EYE_R, CROWN - 1.2, segs=96, up=False)
cornice(KX, KZ, KR + 1.0, CROWN, segs=96, size=0.9)
parapet(KX, KZ, KR + 0.6, (CROWN, CROWN), D(8), D(344))
lathe('gold', [(EYE_R, CROWN), (EYE_R, SUMMIT)], EX, EZ, 40, flip=True)
lathe('gold', [(EYE_R + 0.7, CROWN), (EYE_R + 0.7, CROWN + 0.35), (EYE_R, CROWN + 0.35)], EX, EZ, 40)
for k in range(6):
    x, _, z = polar(EX, EZ, EYE_R + 0.5, TAU * k / 6, 0)
    crystal_shard(x, CROWN + 0.3, z, 1.6, 0.3, seed=700 + k)
ROUTE.append(('walk', polar(EX, EZ, EYE_R + 2.5, D(-30), CROWN)))
ROUTE.append(('drop', (EX, CORE_Y, EZ)))
LANDINGS.append(('crown', polar(KX, KZ, 10.0, D(150), CROWN)))
# crown towers on the ring (clear of the stair arrival and the eye); spire tips at 139
for deg in (50, 110, 230, 290):
    x, _, z = polar(KX, KZ, KR - 1.5, D(deg), 0)
    tower(x, z, 2.1, CROWN, 133.6, spire=4.0)
# the crown spire at the back (the tallest point, 140 m)
x, _, z = polar(KX, KZ, KR - 2.5, D(170), 0)
tower(x, z, 3.0, CROWN, 133.4, spire=6.6, windows=4)

# ------------------------------------------------------------------ silhouette pieces (not on the route)
# back tower and two curved arms (top view: three spokes to the back), placed in final coords
with final():
    tower(0, -31.0, 2.6, 66.0, 100.0, spire=7.0, windows=4)
    stalactite(0, 62.0, -31.0, 10, 3.0, seed=300)
    for sx in (-1, 1):
        tower(sx * 15.0, -38.0, 1.8, 66.0, 90.0, spire=5.0)
        stalactite(sx * 15.0, 66.0, -38.0, 7, 1.8, seed=301 + sx)
        for t in range(10):
            f0, f1 = t / 10, (t + 1) / 10
            def arm(f):
                ax, az = sx * 15.0 * f + sx * 10.0 * (1 - f), -38.0 * f - 24.0 * (1 - f)
                ay = 88.0 - 4.0 * f + 3.0 * math.sin(f * math.pi)
                return ax, ay, az
            x0, y0_, z0 = arm(f0); x1, y1_, z1 = arm(f1)
            yaw = math.atan2(x1 - x0, z1 - z0)
            L = math.hypot(x1 - x0, z1 - z0)
            box('stone', ((x0 + x1) / 2, (y0_ + y1_) / 2, (z0 + z1) / 2), (1.6, 2.0, L + 0.3), yaw=yaw)
            box('gold', ((x0 + x1) / 2, (y0_ + y1_) / 2 + 1.05, (z0 + z1) / 2), (1.8, 0.15, L + 0.3), yaw=yaw)
    # front wing towers (top view: the two front legs), hanging below the platform and rising to the keep
    for sx in (-1, 1):
        x, z = sx * 18.0, 31.0
        lathe('stone', [(0.05, 34.0), (1.6, 38.0), (2.8, 42.0), (3.4, 46.0), (3.6, 52.0)], x, z, 20)
        lathe('gold', [(3.45, 47.5), (3.65, 48.0)], x, z, 20)
        crystal_down(x, 34.6, z, 4.0, 0.7, seed=400 + sx)
        tower(x, z, 3.6, 52.0, 108.0, spire=8.0, windows=4)
        for yb in (74.0, 92.0):
            box('stone', (sx * 13.0, yb - 0.6, 25.0), (3.2, 1.2, 9.0), yaw=math.atan2(sx * 5.0, 6.0))
# side turrets on the base rim (left and right)
for deg in (90, 270):
    x, _, z = polar(CX, CZ, R_BASE + 2.4, D(deg), 0)
    with local(x, z, BASE_Y):
        lathe('stone', [(3.6, 52.6), (3.6, BASE_Y)], x, z, 20)
    tower(x, z, 2.6, BASE_Y, 68.0, spire=6.0)
    for k in range(4):
        stalactite(x + 1.2 * math.sin(k), 52.6, z + 1.2 * math.cos(k), 5, 1.3, seed=500 + deg + k)
# the front crystal spine (front centre, over the arches)
for y in (60.0, 69.0, 84.0, 98.0, 112.0):
    rr = RA + 1.2 if y < 74 else (RB + 1.2 if y < 92 else RC + 1.2)
    crystal_shard(CX, y, CZ + rr + 0.4, 3.4, 0.7, (0, 0.0), seed=int(y))
    box('gold', (CX, y + 1.0, CZ + rr + 0.1), (1.8, 2.6, 0.3))

# ------------------------------------------------------------------ save
def fin(p):
    return kit.T(p)
def densify(route):
    out = []
    prev = None
    for kind, v in route:
        if kind == 'walk' and prev is not None and prev[0] == 'walk':
            p, q = prev[1], v
            best = None
            for (cx, cz) in ((CX, CZ), (KX, KZ)):
                rp, rq = math.hypot(p[0] - cx, p[2] - cz), math.hypot(q[0] - cx, q[2] - cz)
                if rp < 12 or rq < 12:
                    continue
                ap, aq = math.atan2(p[0] - cx, p[2] - cz), math.atan2(q[0] - cx, q[2] - cz)
                da = (aq - ap + math.pi) % TAU - math.pi
                score = abs(rp - rq)
                if best is None or score < best[0]:
                    best = (score, cx, cz, rp, rq, ap, da)
            if best and abs(best[6]) > D(8):
                _, cx, cz, rp, rq, ap, da = best
                n = int(abs(da) / D(5))
                for i in range(1, n):
                    t = i / n
                    out.append(('walk', polar(cx, cz, rp + (rq - rp) * t, ap + da * t, p[1] + (q[1] - p[1]) * t)))
        out.append((kind, v))
        prev = (kind, v)
    return out
ROUTE = densify(ROUTE)
R2 = []
for kind, v in ROUTE:
    if kind == 'walkF':
        R2.append(('walk', tuple(v)))
    elif kind in ('walk', 'drop'):
        R2.append((kind, fin(v)))
    else:
        R2.append((kind, v))
ROUTE = R2
for L_ in LADDERS:
    L_['bottom'] = fin(L_['bottom']); L_['top'] = fin(L_['top'])
    dx, dz = L_['top'][0] - L_['bottom'][0], L_['top'][2] - L_['bottom'][2]
    n = math.hypot(dx, dz); L_['face'] = (dx / n, 0.0, dz / n)
LANDINGS = [(n_, fin(p)) for n_, p in LANDINGS]
DEADENDS = [(n_, fin(p)) for n_, p in DEADENDS]
# ------------------------------------------------------------------ game data (gates, checkpoints, knights)
def gate(a_deg, r0, r1, y, cx=CX, cz=CZ):
    p0 = fin(polar(cx, cz, r0, D(a_deg), y)); p1 = fin(polar(cx, cz, r1, D(a_deg), y))
    c = ((p0[0] + p1[0]) / 2, y + 2.0, (p0[2] + p1[2]) / 2)
    w = math.hypot(p1[0] - p0[0], p1[2] - p0[2]) + 0.6
    sx, sz = (p1[0] - p0[0]) / (w - 0.6), (p1[2] - p0[2]) / (w - 0.6)
    return {'pos': c, 'size': (w, 4.0, 0.4), 'face': (-sz, 0.0, sx)}
eye_f = fin((EX, CROWN, EZ))
GATES = [gate(66, RA + 1.0, RA + 6.4, BASE_Y), gate(259, RA + 0.9, RA + 6.6, GAL1), gate(206, RB + 0.9, RB + 6.6, GAL2),
         gate(153.5, RC + 1.0, RC + 6.2, GAL3),
         {'pos': (eye_f[0], CROWN - 0.15, eye_f[2]), 'size': (EYE_R * 2 + 1.2, 0.3, EYE_R * 2 + 1.2), 'face': (0.0, 0.0, 1.0)}]
SPAWNS = [(0, DOCK_Y + 0.3, DZ0 + 6.0), fin(polar(CX, CZ, RA + 3.5, D(138), GAL1 + 0.3)), fin(polar(CX, CZ, RB + 3.0, D(276), TER_A + 0.3)),
          fin(polar(CX, CZ, RC + 3.5, D(222), TER_B + 0.3)), fin(polar(CX, CZ, RC + 3.6, D(232), SUMMIT + 0.3)), fin((EX, CORE_Y + 0.3, EZ - 6.0))]
GOALS = ['Take out the guards on the base terrace', 'Clear the first ring and climb', 'Clear the second ring and climb',
         'Clear the third ring and climb to the summit', 'Take the crown. Drop through the eye', 'Defeat the Dark Knight']
KN = [(0, (-8.0, BASE_Y + 0.2, kit.warp(0, R_BASE - 3, BASE_Y)[1] - 2.0), True), (0, (8.0, BASE_Y + 0.2, kit.warp(0, R_BASE - 3, BASE_Y)[1] - 5.0), True),
      (0, (0.0, BASE_Y + 0.2, kit.warp(0, R_BASE - 3, BASE_Y)[1] - 8.0), True),
      (0, fin(polar(CX, CZ, RA + 7.0, D(45), BASE_Y + 0.2)), False),
      (1, fin(polar(CX, CZ, RA + 7.0, D(250), GAL1 + 0.2)), False), (1, fin(polar(CX, CZ, RA + 3.5, D(232), GAL1 + 0.2)), False),
      (2, fin(polar(CX, CZ, RA + 6.0, D(315), TER_A + 0.2)), False), (2, fin(polar(CX, CZ, RB + 7.0, D(195), GAL2 + 0.2)), False),
      (3, fin(polar(CX, CZ, RB + 6.0, D(255), TER_B + 0.2)), False), (3, fin(polar(CX, CZ, RC + 7.0, D(135), GAL3 + 0.2)), False),
      (4, fin(polar(KX, KZ, 10.0, D(150), CROWN + 0.2)), False), (4, fin(polar(KX, KZ, 10.0, D(240), CROWN + 0.2)), False)]
game = {'version': 2, 'model_scale': 1.0, 'dock': SPAWNS[0], 'core_y': CORE_Y, 'crown_y': CROWN, 'eye': [eye_f[0], eye_f[2], EYE_R],
        'core_c': list(fin((CX, CORE_Y, CZ))), 'core_r': CORE_R,
        'spawns': SPAWNS, 'goals': GOALS, 'barriers': GATES,
        'ladders': [{'bottom': l['bottom'], 'top': l['top'], 'face': l['face']} for l in LADDERS],
        'knights': [{'sec': s_, 'pos': p, 'patrol': pt} for s_, p, pt in KN],
        'bot': [({'act': 'walk', 'p': v} if k == 'walk' else ({'act': 'ladder', 'i': v} if k == 'ladder' else {'act': 'drop', 'p': v})) for k, v in ROUTE],
        'landings': LANDINGS, 'deadends': DEADENDS}
def rnd_(o):
    if isinstance(o, float): return round(o, 3)
    if isinstance(o, (list, tuple)): return [rnd_(x) for x in o]
    if isinstance(o, dict): return {k: rnd_(v) for k, v in o.items()}
    return o
json.dump(rnd_(game), open('out/route2.json', 'w'), indent=1)
data = {'P': kit.P, 'COL': kit.COL, 'ROUTE': ROUTE, 'LADDERS': LADDERS, 'LANDINGS': LANDINGS, 'DEADENDS': DEADENDS,
        'levels': {'dock': DOCK_Y, 'base': BASE_Y, 'gal1': GAL1, 'terA': TER_A, 'gal2': GAL2, 'terB': TER_B, 'gal3': GAL3,
                   'core': CORE_Y, 'summit': SUMMIT, 'crown': CROWN, 'top': TOP, 'eye_r': EYE_R, 'eye': fin((EX, 0, EZ))}}
pickle.dump(data, open('castle.pkl', 'wb'))
n = sum(len(v) for v in kit.P.values())
print('polys', n, {k: len(v) for k, v in kit.P.items()}, 'col', len(kit.COL))
