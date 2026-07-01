# DittoNet V1

A production-grade backend interceptor engine and dashboard for a Flutter-based Transparent Proxy Bridge (DittoNet).
The server acts as the central "Brain" (Rule Engine), the "Single Source of Truth" for interception rules, and the "Control Center" (Real-time Dashboard).

## Setup

1. Create a virtual environment:
   ```bash
   python -m venv .venv
   ```

2. Activate the virtual environment:
   - Windows: `.venv\Scripts\activate`
   - Linux/Mac: `source .venv/bin/activate`

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
   Or install the package locally:
   ```bash
   pip install -e .
   ```

## Usage

Run the server using the provided `test_implementation.py` script:

```bash
python test_implementation.py
```

Then visit the dashboard at `http://localhost:5000`.

## API Contracts

- `GET /api/health`: Health check.
- `GET/POST /api/sync/workspace`: Workspace synchronization for the mobile client.
- `POST /api/intercept/request`: Request interception phase.
- `POST /api/intercept/response`: Response interception phase.
- `POST /api/replay`: Replay a request from the dashboard.

## ⭐ Open Source & Support

- **GitHub Repository**: [MassoudiR/DittoNet](https://github.com/MassoudiR/DittoNet)

If DittoNet enhances your development and interception workflows, consider supporting the author:
- **USDT (Tron TRC20)**: `TNhAhjhvw1c1CyayxreLNxhD8u8UViLiY5`
- **Bitcoin (BTC)**: `16xTx25nuwDQ9gKwumJgjJCfRXVgag27vP`
