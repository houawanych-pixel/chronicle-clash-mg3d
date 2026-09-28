import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
names=['EXTERIOR INFILTRATION','SECURITY HUB','LIVING QUARTERS','RESEARCH / DEVELOPMENT','MANUFACTURING / DETENTION','EXTRACTION']
briefs=[
 ['LAND WITHOUT A TRACE','A maintenance fault has opened a route into the facility.','Cut the perimeter scanner, recover Level 1 access, then enter security.'],
 ['BREAK THE WATCH','The security hub controls the internal laser grid.','Read the maintenance log. Isolate its circuits in the correct order.'],
 ['FIND THE MISSING SCIENTIST','The barracks hold a Level 2 credential and the detention transfer record.','Search the duty desk, open the officer locker, and trace the prisoner.'],
 ['STEAL THE RESEARCH','The archive is interlocked with a three-valve cooling system.','Balance the circuit, authenticate with Level 2, and recover the data.'],
 ['STOP THE ASSEMBLY LINE','A captive scientist is being held beside the manufacturing floor.','Shut down the conveyor, release the cell, and lead them to the lift.'],
 ['GET EVERYONE OUT','The helipad defense grid is still active.','Disable its emitter, send the extraction signal, and survive until pickup.']]
# id, display, kind, xz, prerequisites
specs=[
 [('perimeter','SCANNER POWER','switch',[12,10],[]),('card1','LEVEL 1 KEYCARD','card1',[-6,-7],['perimeter']),('gate1','SECURITY ACCESS','door',[17,-5],['card1']),('exit1','SECURITY LIFT','exit',[23,-7],['gate1'])],
 [('log','MAINTENANCE LOG','note',[-20,-9],[]),('grid','CIRCUIT PANEL','sequence',[-5,-8],['log']),('security','LASER GRID ISOLATOR','switch',[10,-15],['grid']),('exit2','BARRACKS LIFT','exit',[25,-7],['security'])],
 [('duty','DUTY DESK','note',[-20,0],[]),('card2','OFFICER LOCKER / L2','card2',[-13,-12],['duty']),('transfer','PRISONER TRANSFER LOG','note',[13,-12],['card2']),('exit3','RESEARCH LIFT','exit',[15,10],['transfer'])],
 [('cooling','COOLANT VALVES','valves',[-18,-10],[]),('archive','RESEARCH ARCHIVE','data',[7,-10],['cooling']),('exit4','ASSEMBLY LIFT','exit',[14,12],['archive'])],
 [('conveyor','CONVEYOR CONTROL','timing',[1,-4],[]),('rescue','DETENTION RELEASE','rescue',[16,10],['conveyor']),('exit5','SERVICE LIFT','exit',[-23,-8],['rescue'])],
 [('emitter','AA EMITTER','switch',[-20,-7],[]),('beacon','EXTRACTION RADIO','beacon',[5,-6],['emitter']),('exit6','HELICOPTER','finish',[22,7],['beacon'])]]
starts=[[-18,8],[-13,5],[-13,10],[-18,7],[-14,9],[-19,-3]]
patrols=[[[[10,10],[13,6]],[[1,-6],[14,-6]]],[[[-13,5],[-7,5]],[[-8,-10],[1,-10]],[[20,-6],[26,-6]]],[[[-20,-12],[-8,-12]],[[9,-7],[17,-7]]],[[[-20,-2],[-9,-2]],[[5,-10],[11,-10]],[[7,12],[15,12]]],[[[-10,3],[10,3]],[[1,-6],[12,-6]],[[-24,-7],[-20,-7]]],[[[-9,5],[5,5]],[[16,7],[24,7]]]]
for i in range(6):
 nav=json.load(open(root/f'assets/stages/nav{i+1}.json'));cells={(x,z):h for x,z,h in nav['cells']};off=nav['offset'];step=.5
 def snap(p):
  candidates=[(x,z) for x,z in cells if all((x+dx,z+dz) in cells for dx,dz in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)])]
  x,z=min(candidates,key=lambda q:(off+q[0]*step-p[0])**2+(off+q[1]*step-p[1])**2)
  return [round(off+x*step,3),round(cells[x,z]+.12,3),round(off+z*step,3)]
 points=[{'id':id,'name':name,'kind':kind,'at':snap(p),'requires':req} for id,name,kind,p,req in specs[i]]
 mission={'asset':'res://assets/stages/'+sorted((root/'assets/stages').glob('HOVAGI*.glb'))[i].name,'name':names[i],'tag':briefs[i][0],'brief':briefs[i][1:],'start':snap(starts[i]),'points':points,'routes':[[snap(p) for p in route] for route in patrols[i]],'goals':[p['id'] for p in points]}
 json.dump(mission,open(root/f'assets/stages/mission{i+1}.json','w'),indent=2)
 print(i+1,mission['start'],[(p['id'],p['at']) for p in points])
