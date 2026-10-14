# TODO 

## Kernels

**advec_mom_kernel_c.c**:

- Hoist first four loops (post_vol/pre_vol,
node_flux, node_mass_post, node_mass_pre) out of velocity loop, these do not need to be recalculated.
- `pre_vol` written over haloed grid, never read. Remove dead store
- velocity update write-allocate remove (no temporal store)

**advec_cell_kernel_c.c**:

- pre_mass, post_mass, post_ener and advec_vol as temporaries instead of writing and reading from memory in same iter.
- `post_vol` written over haloed grid, never read. Remove dead store

**revert_kernel_c.c/reset_field_kernel_c.c**:

- revert kernel without copy by swapping memory ownership

**calc_dt_kernel_c.c**:

- fused reduction to save a mesh store and reload for dt_min

**Jort**

- advec_mom
- calc_dt

**Sergiu**

- advec_cell
- revert/reset field kernels