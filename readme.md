# Ubuntu Server Security & Docker Helper Scripts

A pair of Bash scripts and an Ansible playbook to quickly secure a fresh Ubuntu server, lock down SSH, configure UFW, and install Docker.

---

## 🔍 Repository Contents

- **secure_server.sh**  
  Automates:
  - System update & upgrade  
  - Creation of a non‑root user with sudo privileges  
  - SSH hardening (custom port, root login disabled, allowed users)  
  - UFW setup (default deny incoming, allow SSH & Docker ports)  

- **install_docker.sh**  
  Automates:
  - Installing Docker Engine & CLI  
  - Enabling and starting Docker service  
  - Optionally adding your user to the `docker` group  

- **server_req_playbook.yaml**  
  An Ansible playbook that:
  - Installs any additional packages you need (e.g. `htop`, `ufw`, `curl`, etc.)  
  - Applies any further configuration you define in `inventory.ini`

- **inventory.ini**  
  Your Ansible inventory file with one or more target hosts.

---

## 🚀 Quick Start

> These steps assume you have **root** SSH access to your fresh Ubuntu server, and you’re running commands from your **local** machine.

1. **Upload & run the security script**  
   ```bash
   scp secure_server.sh root@YOUR_SERVER_IP:~
   ssh root@YOUR_SERVER_IP
   chmod +x secure_server.sh
   ./secure_server.sh
````

This will:

* Create a new sudo user
* Harden SSH on port **2220**
* Enable UFW with basic rules

2. **Set up your SSH key locally**

   ```bash
   # On your laptop/desktop
   ssh-keygen -t rsa -b 4096
   ssh-copy-id -p 2220 NEW_USERNAME@YOUR_SERVER_IP
   ```

3. **Verify key‑based login**

   ```bash
   ssh -p 2220 NEW_USERNAME@YOUR_SERVER_IP
   ```

4. **Install Docker**

   ```bash
   scp install_docker.sh NEW_USERNAME@YOUR_SERVER_IP:~
   ssh -p 2220 NEW_USERNAME@YOUR_SERVER_IP
   chmod +x install_docker.sh
   ./install_docker.sh
   ```

5. **(Optional) Run Ansible playbook for extras**

   ```bash
   # On your local machine
   ansible-playbook -i inventory.ini server_req_playbook.yaml -K
   ```

   You’ll be prompted for the sudo password of your NEW\_USERNAME.

---

## ⚙️ Script Details

### `secure_server.sh`

* **Port**: 2220
* **UFW**:

  * Deny all incoming by default
  * Allow outgoing by default
  * Allow SSH on port 2220
* **SSH Config Changes**:

  * `PermitRootLogin no`
  * `AllowUsers NEW_USERNAME`

### `install_docker.sh`

* Installs the latest Docker Engine from Docker’s official repo
* Enables & starts the Docker service
* Adds `NEW_USERNAME` to the `docker` group for non‑root Docker use

---

## 📝 Customization

* Change `SSH_PORT`, `NEW_USERNAME`, or UFW rules at the top of each script.
* Extend the Ansible playbook (`server_req_playbook.yaml`) with any other roles or tasks you need.

---

## 📜 License

This project is released under the [MIT License](LICENSE). Feel free to adapt and share!

