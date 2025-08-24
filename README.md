# Flutter + Python Integration Project

This project integrates a Flutter frontend (`main.dart`) with a Python backend (`tina_core.py`).  
It combines a **mobile UI** with **backend processing** to create a complete cross-platform application.

## 📌 Features
### Frontend (Flutter)
- Uses Flutter Material Design widgets
- Makes API requests

### Backend (Python)
- Python backend core logic


## 🚀 Getting Started

### Prerequisites
Ensure you have the following installed:
- [Flutter](https://docs.flutter.dev/get-started/install)
- [Dart](https://dart.dev/get-dart)
- [Python 3.x](https://www.python.org/downloads/)
- `pip` for Python dependencies

### 🔧 Installation

Clone the repository:
```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name
```

#### Setup Python Backend
```bash
cd backend   # if tina_core.py is in a backend folder
pip install -r requirements.txt
```
Run the backend:
```bash
python tina_core.py
```

#### Setup Flutter Frontend
```bash
cd frontend   # if main.dart is in a Flutter project
flutter pub get
flutter run
```

## 📂 Project Structure
```
project-root/
│── frontend/
│   └── lib/main.dart       # Flutter entry point
│── backend/
│   └── tina_core.py        # Python backend logic
│── README.md               # Project documentation
```

## 🤝 Contributing
1. Fork the repo  
2. Create a new branch (`feature/your-feature`)  
3. Commit your changes  
4. Push to your fork  
5. Open a Pull Request  

## 📄 License
This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
