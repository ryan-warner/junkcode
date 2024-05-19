import random

people = ["Ryan", "Alexander", "Oliver", "Mom", "Dad"]
people_dict = {}

numbers = list(range(0,26))
# For each person in the list of people draw one number without replacement in the range 0-25, until the number of numbers remaining is less than the length of the number of people
while (len(numbers) - len(people)) > len(people):
    for person in people:
        draw = random.choice(numbers)
        if person not in people_dict.keys():
            people_dict[person] = []

        # Convert number to letter
        letter = chr(draw + 65)
        people_dict[person].append(letter)
        numbers.remove(draw)

extras = [chr(number + 65) for number in numbers]

print(people_dict)
print(extras)

# Save to file in same directory
with open("Desktop/letters.txt", "w") as file:
    for person in people_dict.keys():
        file.write(f"{person}: {people_dict[person]}\n")
    file.write(f"\nExtras: {extras}\n")