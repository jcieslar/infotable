# Security policy

## Supported versions

Only the latest released minor version of the `infotable` gem receives security fixes.

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Report it privately, in this order of preference:

1. GitHub: [Report a vulnerability](https://github.com/jcieslar/infotable/security/advisories/new) on the Security tab.
2. Email: jakub@infovation.pl

Include the gem version, the Rails and database versions, and the steps (or a failing test) that show the problem. Reports about SQL injection, XSS, CSV/formula injection, authorization bypass in `authorize`, or leaking of columns that are not shown are especially welcome.

You can expect an answer within 5 working days. A confirmed problem is fixed in a patch release and credited in the changelog and the advisory, unless you prefer to stay anonymous. Please give us a reasonable time to release a fix before you disclose the details.
