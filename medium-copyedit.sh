# This script will deploy all the bits and pieces required for the AskHuman-based proofreading service onto one box.
# Ruby on port 6000, Node on port 3000, Python via 0MQ on port 4242

set -e
sudo apt-get update
yes | sudo apt-get install git

# Step 0. Checkout HEAD.

cd ~
git clone https://github.com/lmeyerov/devnull.git
git clone https://github.com/lsb/turk-rest-api.git

echo "cat - > ~/turk-rest-api/turk-credentials.rb"
cat - > ~/turk-rest-api/turk-credentials.rb
echo Mandrill API Key?
read $mandrillApiKey

sudo chmod 777 /etc/init/

# Step 1. Install Node.

yes | sudo apt-get install python-software-properties python g++ make
echo | sudo add-apt-repository ppa:chris-lea/node.js
sudo apt-get update
yes | sudo apt-get install nodejs
yes | sudo apt-get install libzmq-dev

# Step 2. Install Ruby.

curl -L https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install 1.9.3
rvm use 1.9.3
yes | sudo apt-get install libxslt-dev libxml2-dev
gem install bundler

# Step 3. Install SQLite & nginx.

yes | sudo apt-get install libsqlite3-dev nginx

# Step 4. Install nltk.

yes | sudo apt-get install python-dev
wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | sudo python
yes | sudo apt-get install python-pip
sudo pip install -U numpy pyyaml nltk
sudo python -m nltk.downloader -d /usr/share/nltk_data punkt
yes | sudo apt-get install libevent-dev

# Step 5a. Install dependencies for turk-rest-api.

cd ~/turk-rest-api
bundle install

# Step 5b. Install turk-rest-api upstart scripts.

(echo "start on runlevel [2345]" ; echo script ; echo "  cd `pwd`"; echo "  sudo -u ubuntu bash -c 'source /home/ubuntu/.rvm/scripts/rvm; rvm use 1.9.3; ./putget-server.sh'" ; echo end script) > /etc/init/turk-rest-api-putget-server.conf
(echo "start on runlevel [2345]" ; echo script ; echo "  cd `pwd`"; echo "  sudo -u ubuntu ./turk-io-daemon.sh" ; echo end script) > /etc/init/turk-rest-api-turk-io-daemon.conf

# Step 6a. Install dependences for node copyedit server.

cd ~/devnull/copyedit/server/
npm install

# Step 6b. Install node copyedit server upstart scripts.

(echo "start on runlevel [2345]" ; echo script ; echo "  cd `pwd`"; echo '  sudo -u ubuntu node server.js' \' '{"name": "Leo Meyerovich", "email": "lmeyerov+mtbc@gmail.com", "mandrillApiKey": "'${mandrillApiKey}'", "askHuman": "http://localhost/human/", "proofUrl": "http://localhost:3000/"}' \' \> stdout 2\> stderr; echo end script) > /etc/init/copyedit-node-server.conf

# Step 7. Install dependencies for nltk wrapped with a zmq wrapper

cd ~/devnull/copyedit/serverSplitter
sudo pip install -r requirements.txt

# Step 7b. Install nltk wrapped with a zmq wrapper.

(echo "start on runlevel [2345]" ; echo script ; echo "  cd `pwd`"; echo "  sudo -u ubuntu python dumpTex.py" ; echo end script) > /etc/init/nltkzmq-python-server.conf

# Step 8. Install nginx configs.

(echo 'upstream askhuman { server localhost:6000; }' ;
 echo 'upstream nodecopyedit { server localhost:3000; }' ;
 echo 'server {' ;
 echo 'location /human/ { rewrite /human/(.*) /$1 break; proxy_pass http://askhuman; }' ;
 echo 'location / { proxy_pass http://nodecopyedit; }';
 echo '}') | sudo tee /etc/nginx/sites-available/default > /dev/null
