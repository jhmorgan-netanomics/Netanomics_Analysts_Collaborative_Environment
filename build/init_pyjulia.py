def init_pyjulia():
    from julia.api import Julia
    return Julia(compiled_modules=False)

# Initialize PyJulia
jl = init_pyjulia()

from julia import Main
print("PyJulia initialized successfully.")
