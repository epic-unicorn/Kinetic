/// Task priority — maps to int column values 0–3.
enum TaskPriority {
  none, // 0
  low, // 1  !
  medium, // 2  !!
  high, // 3  !!!
}

/// Auto-detected task category used by the load analyser and proposals.
enum TaskCategory { household, health, admin, school, finance, other }

/// Proposal status in the partner inbox.
enum ProposalStatus { pending, accepted, dismissed, rejected }
