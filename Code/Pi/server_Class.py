import socket

class MatlabServer:
    def __init__(self, host='0.0.0.0', port=5000):
        """
        host: IP to bind to (default 0.0.0.0 for all interfaces)
        port: Port number (default 5000)
        action_callback: A function that takes a list of inputs and returns a result string.
        """
        self.host = host
        self.port = port
        self.server_socket = None
        self.connection = None
        self.address = None

    def establish_server(self):
        """
        Creates the socket, binds to the port, and enables listening.
        Call this ONCE before starting the input loop.
        """
        try:
            print("Waiting for MATLAB to connect...")
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen()
            self.connection, self.address = self.server_socket.accept()
            print(f"Connected by: {self.address}")
        except Exception as e:
            print(f"Failed to establish server: {e}")
            self.server_socket = None


    def listen_and_return(self):
        print("Listening...")
        # 1. Receive Data
        data = self.connection.recv(1024)
        if not data: return None

        msg = data.decode('utf-8').strip()
        if msg == 'exit':
            print("Exit command received.")
            return None

        # 2. Parse Data (Strings & Numbers)
        parts = msg.split(',')
        parsed_data = []
        for p in parts:
            try:
                parsed_data.append(float(p))
            except ValueError:
                parsed_data.append(p)

        print(f"Received Input: {parsed_data}")
        self.connection.sendall("Pi received input".encode('utf-8'))
        return parsed_data

    def print(self, string):
        self.connection.sendall(string.encode('utf-8'))
