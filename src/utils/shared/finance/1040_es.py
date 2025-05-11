try:
    w2_income = float(input("Enter your combined W2 income for 2025: "))
    withheld_tax = float(input("Enter your combined tax already withheld by employers: "))
    q1_1099_income = float(input("Enter your combined Q1 1099 income for 2025: "))

    tax_rate = 0.24  # Approximate tax rate tends to be around 24%

    # Adjust your 1099 income by the tax rate and subtract any tax already withheld
    q1_estimated_tax = (q1_1099_income * tax_rate) - (withheld_tax / 4)
    print("Your Q1 2025 estimated tax payment for your 1099 income is: $", round(q1_estimated_tax, 2))

except ValueError:
    print("Please enter a valid number for your incomes and withholdings.")
