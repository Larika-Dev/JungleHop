# Who lives in Cathedral Mount

The 4,000 NPCs are a stand-in population for an invented town, using the
proportions of the real town and university it is modeled on. Numbers live in
`npc_demographics.gd`; `tests/test_population.gd` checks them.

## Undergraduates (30% of NPCs, 1,200 people)

UNC-Chapel Hill, IPEDS Fall Enrollment 2023-24 (fall 2023): 20,681 undergraduates.
Source: https://oira.unc.edu/wp-content/uploads/sites/297/2024/02/IPEDS_Fall_Enrollment_2023-24.pdf

| | Count | Share used |
|---|---|---|
| Women | 12,553 | 60.7% |
| White | 11,184 | 55.3% |
| Asian | 3,076 | 15.2% |
| Hispanic/Latino | 2,021 | 10.0% |
| Black | 1,690 | 8.4% |
| Two or more races | 1,062 | 5.3% |
| U.S. nonresident (international) | 1,094 | 5.4% |
| American Indian | 67 | 0.4% |

"Race unknown" (479) and Pacific Islander (8) are spread across the other groups.

## Town residents (70%: workers, retirees, people between jobs)

Chapel Hill town, 2024 figures as published by Data USA (population 61,607):
non-Hispanic White 38.7k (62.8%), Asian 8.23k (13.4%), Black 6.94k (11.3%),
Hispanic 4.66k (7.6%); the rest (about 4.9%) is two or more races and other groups.
Source: https://datausa.io/profile/geo/chapel-hill-nc
Women are set to 53% of town residents (an estimate; the Census QuickFacts page
could not be fetched from this environment).

## What it drives

Background sets the complexion range (a spread per group, overlapping, never one
color), name pools, hair and eye color odds. Everyone generated is an adult, so
the adult height table applies to all of them; heights do not vary by background.
