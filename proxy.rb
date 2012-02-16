#!/usr/bin/env ruby

require 'socket'
require 'uri'
require 'fileutils'

include Socket::Constants

server = TCPServer.new(2000)

clients = []
buffers = {}

count = 0

FileUtils::mkdir('cache') unless File::exists?('cache')
exit unless File::directory?('cache')

while true
    sockets = [server] + clients
    readable, writable = IO.select(sockets)
    
    readable.each do |sock|
        begin
            if sock == server
                clients << server.accept_nonblock
            else
                begin
                    client, buf = sock, buffers[sock] ||= ''
                    
                    buf << client.read_nonblock(1024)
                    if buf =~ /^.+?\r?\n/
                        bufLines = buf.split("\r\n")
                        firstLine = bufLines[0]
                        method = firstLine.split(' ')[0]
                        url = firstLine.split(' ')[1]
                        http_version = firstLine.split(' ')[2]
                        url = url[1, url.size - 1]# if url[0, 1] == '/'
                        
    #                     url = CGI::escape(url)
                        url.gsub!("!", "%21")
                        
                        uri = URI(url)
                        
                        newurl = uri.path
                        newurl = '/' if newurl.empty?
                        newurl += "?#{uri.query}" if uri.query
                        newurl += "##{uri.fragment}" if uri.fragment
                        
    #                     url = 'http://www.spiegel.de/' + url unless url[0, 4] == 'http'
                        
                        puts "X #{url}"
                        response = `curl --http1.0 -i \"#{url}\" 2> /dev/null`

                        begin
                            if (url.split('.').last.downcase == 'jpg' || url.split('.').last.downcase == 'jpeg')
                                puts "trying convert..."
                                data = response[response.index("\r\n\r\n") + 4, response.size]
                                filename = "cache/flip-#{count}.jpg"
                                count += 1
                                File::open(filename, 'w') do |fout|
                                    fout.write(data)
                                end
                                size = `identify \"#{filename}\"`.split(' ')[2].split('x')
                                width = size[0].to_i
                                height = size[1].to_i
                                percent = ((height.to_f / 610.0) * 100.0).to_i
                                system("convert \"#{filename}\" \"(\" kim.png -resize #{percent}% \")\" -gravity SouthEast -composite \"#{filename}.boo\"")
                                FileUtils::rm(filename)
                                response = response[0, response.index("\r\n\r\n") + 4] 
                                response.sub!(/Content-Length: \d+/, "Content-Length: #{File::size(filename + '.boo')}")
                                response += File::read(filename + '.boo')
                                puts "trying convert...done"
                            end
                        rescue StandardError => e
                            puts "Oops, we had a situation: #{e}"
                        end
                        
                        ['href=', 'src='].each do |tag|
                            offset = 0
                            while true
                                new_offset = response.index(tag, offset)
                                break if new_offset == nil
                                offset = new_offset + 1
                                next unless ['"', "'"].include?(response[new_offset + tag.size, 1])
                                ins = 'http://localhost:2000'
                                if response[new_offset + tag.size + 1, 4] != 'http' && 
                                response[new_offset + tag.size + 1, 1] != "'" &&
                                response[new_offset + tag.size + 1, 1] != '"'
                                    ins += '/http://' + uri.host
                                end
                                if response[new_offset + tag.size + 1, 1] != '/'
                                    ins += '/'
                                end
                                response.insert(new_offset + tag.size + 1, ins)
                        #         puts "Fixed that: [#{response[new_offset + tag.size - 20 , 100].gsub("\t", ' ').gsub("\n", ' ').gsub("\r", ' ')}]"
                            end
                        end

                        client.write(response)
                        client.close
                        
                        buffers.delete(client)
                        clients.delete(client)
                    end
                rescue StandardError => e
                    puts "Oops, we had a situation: #{e}"
                    client.close
                    
                    buffers.delete(client)
                    clients.delete(client)
                end
            end
        end
    end
end