import random

def fuzz(code):
  chars = list(code)
  num_chars = len(chars)
  num_mutations = random.randint(1, num_chars)
 
  for i in range(num_mutations):
    char_index = random.randint(0, num_chars - 1)
    chars[char_index] = chr(random.randint(0, 255))
 
  return ''.join(chars)
 
print(fuzz(__file__))
