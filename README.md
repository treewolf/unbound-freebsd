# unbound-freebsd
## Purpose
Update unbound's blocklist automatically.
Script is run from a cron job.

## General overview
1. Fetches open source block lists
1. Parses lists according to unbound's syntax
1. Backs up old block lists if any exists
1. Loads new list and runs config check
1. If config passes test then reload unbound service
1. If config fails, then revert to last valid lists, and do not reload unbound service
1. Leave message somewhere, preferrably in the kernel messages

## What I am running
- FreeBSD 12.2-RELEASE on a raspberry pi 3b
- unbound-1.10.1
- Block lists are sourced from https://github.com/blocklistproject/Lists
