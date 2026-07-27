---
name: dev-pytorch
description: Use for PyTorch code, and for reading a PyTorch reference implementation before porting it: torch, torch.nn, torch.optim, DataLoader, tensors, modules, training loops, GPU/device placement, autograd, train/eval mode, AMP, vectorization, torch.compile, weight layouts, RNG sites, Lightning hooks.
---

# Skill: Dev PyTorch

## Rules

- Keep tensors and modules on the intended device; avoid silent CPU/GPU movement.
- Use `model.train()` for training and `model.eval()` for evaluation/inference.
- Use `torch.no_grad()` or `torch.inference_mode()` for inference.
- Prefer vectorized operations and readable shape transforms; use `einops` when clearer.
- Use `torch.compile` for stable heavy models/functions when compatible.
- Save/load normal checkpoints with `state_dict`.
- Make loss, optimizer, scheduler, zero-grad, backward, clip, and step order explicit.

## Workflow

1. State shapes and devices near dependent code.
2. Implement simple eager logic first.
3. Verify forward output, loss, gradients, and parameter update.
4. Add `torch.compile` only after correctness.
5. Keep data loading, logging, checkpointing, and plotting outside hot paths.

## Idioms

```python
# Training step — order is mandatory
optimizer.zero_grad()
loss = criterion(model(x), y)
loss.backward()
torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
optimizer.step()

# Eval — always pair mode switch with no_grad
model.eval()
with torch.no_grad():
    preds = model(x)
model.train()

# Checkpoint — state_dict only, never pickle the module
torch.save({"model": model.state_dict(), "opt": optimizer.state_dict()}, path)
ckpt = torch.load(path, map_location=device, weights_only=True)
model.load_state_dict(ckpt["model"])
optimizer.load_state_dict(ckpt["opt"])
```

## Reading a Reference Implementation

The usual reason to open PyTorch here is to port it. `dev-jax-port` owns the
parity protocol; this is what that protocol needs from the PyTorch side.

- **Find every RNG site**, not just `torch.manual_seed`: weight init, dropout,
  DataLoader shuffle and its per-worker generator, augmentation, and any
  `random`/`numpy` call inside the dataset. A port that re-samples rather than
  replaying these cannot be compared against the reference at all.
- **Layouts are conventions, not facts.** `nn.Linear` stores weight as
  `(out, in)` and computes `x @ W.T`; conv layouts and fused gate orderings
  (LSTM/GRU `i,f,g,o`) differ across frameworks. Read the shape, never assume it.
- **The harness does things the model file does not show.** Under Lightning or a
  similar trainer, optimizer construction, LR scheduling, gradient clipping,
  accumulation, AMP casting, and `zero_grad` placement live in hooks. Read the
  harness before concluding the training step is what the module implies.
- **Note what silently changes numbers**: `.train()` vs `.eval()` for dropout and
  BatchNorm running statistics, `.detach()` placement, in-place ops, and whether
  the loss reduces by `mean` or `sum` and over which axes.
- Check the reference's own tests and comments for invariants the implementation
  never restates.

## Anti-Patterns

- `.item()` in hot loops — always forces a CPU sync.
- In-place ops that break autograd or compilation.
- Detached tensors in training paths unless intentional.
- Pickling full models for ordinary checkpoints.

## Related Skills

- `dev-jax-port` when reading this reference is the prelude to porting it — that skill owns the replay/parity protocol.
- `debug-ml-research` for plausible-but-wrong ML runs.
- `dev-ml-perf` when the job is slow or OOMs — name the bottleneck before tuning here.
- `dev-python` for packaging/test tooling.
- `dev-viz` for plotting outputs.
