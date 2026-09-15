import pandas as pd
import matplotlib.pyplot as plt
import io

# Your CSV data
csv_data = """ArraySize,Copy_Avg,Copy_Min,Copy_Max,Scale_Avg,Scale_Min,Scale_Max,Add_Avg,Add_Min,Add_Max,Triad_Avg,Triad_Min,Triad_Max
787500,217675.8,107853.5,238055.1,221443.3,144789.7,242423.1,249141.6,138105.1,274298.8,239146.8,135046.6,266014.6
1575000,104799.4,20672.1,145587.4,98511.3,14204.6,131955.6,80852.9,25383.4,101371.3,91261.1,22730.4,123573.4
3150000,52095.5,21656.9,58818.3,54756.1,16987.5,62933.3,51052.2,33144.1,55835.4,51375.2,27751.6,56291.4
6300000,49607.6,31848.3,53789.5,46601.3,24705.5,49974.7,43687.7,29929.6,47045.9,45130.3,33855.4,48820.5
12600000,50127.7,41193.1,52569.0,44698.0,37958.9,46644.5,44641.9,40068.2,46732.2,45382.1,39837.9,47273.9
25200000,51712.9,44860.3,53794.7,43729.0,38724.6,45251.6,45487.3,40143.0,47320.6,45621.9,39828.5,47356.8
50400000,51913.6,45618.4,53752.8,42757.4,38174.4,44380.6,45700.4,40698.5,47352.0,45534.4,41300.5,47482.2
100800000,51985.8,47407.5,54142.6,42064.9,38270.7,43784.5,45663.9,43141.4,47223.3,45509.9,42551.1,47237.1"""

# Load data
df = pd.read_csv(io.StringIO(csv_data))

# Convert MB/s to GB/s for a cleaner y-axis
for col in df.columns:
    if col != 'ArraySize':
        df[col] = df[col] / 1000

# ==========================================
# 1. Central Values Plot (One PNG)
# ==========================================
plt.figure(figsize=(8, 6))
plt.plot(df['ArraySize'], df['Copy_Avg'], marker='o', label='Copy')
plt.plot(df['ArraySize'], df['Scale_Avg'], marker='s', label='Scale')
plt.plot(df['ArraySize'], df['Add_Avg'], marker='^', label='Add')
plt.plot(df['ArraySize'], df['Triad_Avg'], marker='d', label='Triad')

plt.xscale('log')
plt.title('STREAM Benchmark: Central Values')
plt.xlabel('Array Size (Elements)')
plt.ylabel('Bandwidth (GB/s)')
plt.grid(True, which="both", ls="--", alpha=0.5)
plt.legend()
plt.tight_layout()

# Save the first figure
plt.savefig('stream_central_values.png', dpi=300)
plt.close() # Close to start a new, clean figure

# ==========================================
# 2. Variability Plots (Two subplots, One PNG)
# ==========================================
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))

# --- Plot 2A: Copy & Triad Variability ---
ax1.plot(df['ArraySize'], df['Copy_Avg'], color='tab:blue', marker='o', label='Copy Avg')
ax1.fill_between(df['ArraySize'], df['Copy_Min'], df['Copy_Max'], color='tab:blue', alpha=0.2, label='Copy Min/Max')

ax1.plot(df['ArraySize'], df['Triad_Avg'], color='tab:red', marker='d', label='Triad Avg')
ax1.fill_between(df['ArraySize'], df['Triad_Min'], df['Triad_Max'], color='tab:red', alpha=0.2, label='Triad Min/Max')

ax1.set_xscale('log')
ax1.set_title('Variability: Copy & Triad')
ax1.set_xlabel('Array Size (Elements)')
ax1.set_ylabel('Bandwidth (GB/s)')
ax1.grid(True, which="both", ls="--", alpha=0.5)
ax1.legend()

# --- Plot 2B: Scale & Add Variability ---
ax2.plot(df['ArraySize'], df['Scale_Avg'], color='tab:orange', marker='s', label='Scale Avg')
ax2.fill_between(df['ArraySize'], df['Scale_Min'], df['Scale_Max'], color='tab:orange', alpha=0.2, label='Scale Min/Max')

ax2.plot(df['ArraySize'], df['Add_Avg'], color='tab:green', marker='^', label='Add Avg')
ax2.fill_between(df['ArraySize'], df['Add_Min'], df['Add_Max'], color='tab:green', alpha=0.2, label='Add Min/Max')

ax2.set_xscale('log')
ax2.set_title('Variability: Scale & Add')
ax2.set_xlabel('Array Size (Elements)')
ax2.set_ylabel('Bandwidth (GB/s)')
ax2.grid(True, which="both", ls="--", alpha=0.5)
ax2.legend()

# Save the second figure
plt.tight_layout()
plt.savefig('stream_variability.png', dpi=300)
plt.show()