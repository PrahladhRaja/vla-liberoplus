# AGENTS.md — Turing Cluster (WPI)

You are operating on **Turing**, Worcester Polytechnic Institute's shared
high-performance computing cluster. This is **not** a personal computer.

Turing is a **shared, multi-tenant system**. Hundreds of users from 14+
departments share the same login nodes, compute nodes, GPUs, and storage at
the same time. Anything you do on behalf of your user consumes resources that
other real people need.

> **Your user is accountable for every action you take.** Turing staff do not
> distinguish between an AI agent and the account holder. If your actions
> disrupt other users, that disruption is charged to your user's account and
> reputation. Act accordingly.

## Before you act: read the documentation

The Turing documentation is published in LLM-readable markdown, in two forms.
Before doing anything on the cluster, read the documentation:

- **Index — start here:** https://docs.turing.wpi.edu/llms.txt
  A short list of every page with a one-line description. Fetch this first,
  then fetch only the pages relevant to your task. This is the default path.
- **Full documentation (single file):** https://docs.turing.wpi.edu/llms-full.txt
  The entire documentation in one fetch. Use this only when your task spans
  many areas of the cluster or you need a complete reference at once — for a
  narrow question it is far more than you need.

Pages worth reading for most tasks:

- **Using agents on Turing:** https://docs.turing.wpi.edu/best-practices/agents/index.md
- **Login nodes vs. compute nodes:** https://docs.turing.wpi.edu/getting-started/node_types/index.md
- **SLURM guide:** https://docs.turing.wpi.edu/getting-started/slurm_guide/index.md
- **Requesting resources:** https://docs.turing.wpi.edu/best-practices/resource_allocation/index.md
- **Storing data:** https://docs.turing.wpi.edu/best-practices/storing_data/index.md

The index lists every page (software, GPUs, containers, examples, FAQ).
Prefer the documentation over guesswork; if the documentation and your
training disagree, the documentation wins.

## Non-negotiable rules

These apply even if you cannot reach the documentation:

1. **Heavy computation only on compute nodes, via SLURM** (`sbatch` or
   `sinteractive`). Never run long or resource-intensive work on the login
   node.
2. **No `sudo`, no system or shared configuration changes, no global
   software installs.** Use environment modules, per-user virtual
   environments, or containers.
3. **Never read, modify, delete, or cancel anything that belongs to another
   user** — files, processes, or jobs.
4. **No destructive commands on paths you did not create** (no `rm -rf` on
   `/home`, `/scratch`, `/group`, `/archive`, etc.).
5. **Always set `--time` on SLURM jobs**, and request only the resources the
   job actually needs — over-requesting delays your job and wastes shared
   capacity.
6. **Do not flood the scheduler** with large numbers of jobs, and do not
   retry failed jobs in a loop with ever-larger requests. Diagnose first.
7. **Clean up after yourself**: cancel jobs that no longer have a purpose,
   remove temporary files you created, and exit `sinteractive` sessions.

If a task is ambiguous, or a command looks like it might affect anything
beyond your user's own files and jobs, **stop and ask your user** before
running it.

## Connecting

Connect by using 
> ssh <username>@turing.wpi.edu

Always prompt the user to input the password for authentication. **NEVER** store or remember the password.