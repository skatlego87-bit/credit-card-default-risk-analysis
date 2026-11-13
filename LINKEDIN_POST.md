# LinkedIn post (draft: edit, add a Power BI screenshot and your GitHub link)

Banks don't lose money on customers who are *always* late. They lose it on customers who looked fine until it was too late.

For my second portfolio project I took 24,000 credit-card customers from a bank (NT$1.2bn in balances, 22% defaulting the next month) and asked:

**How early can we see default coming, and who should collections call first?**

What I did: cleaned and checked the data in SQL (found that "1 month late" was only coded in the latest month, which would have quietly distorted any "months late" history), then built the dashboard in Power BI.

What I found:
- Customers 2+ months late defaulted 70% of the time. By then it's largely too late.
- Customers just 1 month late defaulted 34%. That's the real intervention window.
- Three simple, explainable rules reach 59% of future defaulters by contacting just 27% of customers
- 1,119 customers looked "current" but had paid nothing on a balance or had a history of lateness. They defaulted at 35%, invisible to a plain "days late" report.
- Sex and marital status differ in default rates, but I kept them out of the rules and used them only to monitor fairness.

What I'd recommend: act at 1 month late, send 2+ months straight to collections, add the hidden "looks current but isn't" group to the watch-list, and pilot with a control group before rolling anything out.

I also wrote up the limitations (one bank, 2005, observational data, rules tuned on the same data), because numbers without caveats are decoration.

SQL, Power BI files and full write-up: [GitHub link]

#DataAnalytics #SQL #PowerBI #Banking #CreditRisk #Statistics
