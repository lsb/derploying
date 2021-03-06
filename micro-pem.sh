sudo apt-get update
echo Y | sudo apt-get install git
sudo chmod 777 /etc/init/

echo Y | sudo apt-get install libsqlite3-dev nginx s3cmd lame

curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install jruby
rvm use jruby
echo y | sudo apt-get install libxslt-dev libxml2-dev
gem install bundler

(echo "start on runlevel [2345]" ; echo script ; echo sudo -u ubuntu bash -c \'source ~/.rvm/scripts/rvm\; cd ~/pem\; ruby app.rb -p 6000 -e production\' ; echo end script) > /etc/init/pem-app.conf

(echo "
upstream pem { server localhost:6000; }
upstream askhuman { server localhost:4000; }
upstream stol { server localhost:5000; }
server {
  location / { proxy_pass http://pem; }
  #server_name *.poetaexmachina.com *.poetaexmachina.net;
}") | sudo tee /etc/nginx/sites-available/default > /dev/null
