import numpy as np, cv2, sys
z = np.load('terrain_h.npy'); wl = np.load('water_h.npy'); PX = 786.76 / 2048
gy, gx = np.gradient(z, PX)
slope = np.degrees(np.arctan(np.hypot(gx, gy)))
# hillshade
az, alt = np.radians(315), np.radians(40)
nx, ny, nz = -gx, gy, np.ones_like(z)
l = np.sqrt(nx**2 + ny**2 + 1); nx, ny, nz = nx/l, ny/l, nz/l
lx, ly, lz = np.cos(alt)*np.sin(az), np.cos(alt)*np.cos(az), np.sin(alt)
hs = np.clip(nx*lx + ny*ly + nz*lz, 0, 1)
# hypsometric tint
t = np.clip(z / 120, 0, 1)
col = np.stack([90 + 60*t, 140 - 20*t + 0*t, 70 + 80*t], -1)  # bgr
col = col * hs[..., None]
wet = ~np.isnan(wl) & (wl > z)
depth = np.where(wet, wl - z, 0)
wc = np.array([150, 110, 40], np.float32)
a = np.clip(0.35 + depth / 6, 0, 0.95)[..., None] * wet[..., None]
col = col * (1 - a) + wc * a
cv2.imwrite(sys.argv[1] if len(sys.argv) > 1 else 'terrain_vis.jpg', cv2.resize(col.astype(np.uint8), (1024, 1024), interpolation=cv2.INTER_AREA))
s = np.clip(slope / 60, 0, 1); sv = cv2.applyColorMap((s*255).astype(np.uint8), cv2.COLORMAP_INFERNO)
cv2.imwrite('slope_vis.jpg', cv2.resize(sv, (700, 700)))
