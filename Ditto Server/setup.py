from setuptools import setup, find_packages

setup(
    name="ditto_interceptor",
    version="1.0.0",
    description="A production-grade backend interceptor engine and dashboard for DittoNet.",
    author="DittoNet Team",
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "Flask",
        "Flask-SocketIO",
        "requests",
        "eventlet",
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
)
