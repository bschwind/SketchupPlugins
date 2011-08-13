require 'sketchup.rb'

basename = File.basename(__FILE__)
unless file_loaded?(basename)
	UI.menu("Plugins").add_item("Export Mesh") {MeshExporter.new}
	file_loaded(basename)
end

class MeshExporter
	def initialize
		@save_path = UI.savepanel("Export Mesh", "C://", "Untitled.msh")
		write_faces
	end
	
	def write_faces
		model = Sketchup.active_model	
		entities = model.entities
		faces = entities.find_all {|e| e.typename == "Face"}
		
		model.start_operation("Triangulate")
		
		#Triangulate the mesh
		faces.each do |f|
			if f.vertices.length > 3
				mesh  = f.mesh(0)
				front = f.material
				back  = f.back_material

				f.erase!
				first = entities.length
				entities.add_faces_from_mesh(mesh, 7)
				last = entities.length

				count = last - first

				while 0 < count
					entity = entities[(last - count)]

					if entity.typename == "Face"
						entity.material = front
						entity.back_material = back
					end

					count -= 1
				end
			end
		end
		
		model.commit_operation
		
		my_faces = Array.new
		my_verts = Array.new
		
		#Write the triangle data to file
		faces = entities.find_all {|e| e.typename == "Face"}
		faces.each do |f|
			current_face = MyFace.new
			f.vertices.each do |v|	
				current_vert = MyVertex.new(v.position, f.normal)
				
				#Get a list of vertices we should examine
				possible_verts = Array.new
				my_verts.each_index do|i| 
					if(my_verts[i] == current_vert)
						possible_verts.push(i)
					else 
						nil
					end
				end
				
				if(possible_verts.length == 0)
					#If it's not in our list, add it, and add it to current_face
					my_verts.push(current_vert)
					new_index = my_verts.index(current_vert) #optimize this
					current_face.add_vert(new_index)
				else
					#Look for a vertex we can share
					current_vert_index = nil
					possible_verts.each do |i|
						#puts f.normal.dot(my_verts[i].normal).abs
						if(f.normal.dot(my_verts[i].normal).abs > 0.8)
							current_vert_index = i
						end
					end
					
					if(current_vert_index)
						current_face.add_vert(current_vert_index)
					else
						my_verts.push(current_vert)
						new_index = my_verts.index(current_vert)
						current_face.add_vert(new_index)
					end
				end	
			end
			
			my_faces.push(current_face)
		end
		
		my_verts.each do |v|
			#puts "v #{v.position.to_s}"
		end
		
		my_faces.each do |f|
			#puts f.get_string(" ")
		end
		
		Sketchup.undo
	end
end

class MyFace
	def initialize
		@indices = Array.new
	end
	
	def add_vert(vertex)
		@indices.push(vertex)
	end
	
	def get_string(separator)
		return @indices.join(separator)
	end
end

class MyVertex
	attr_accessor :position
	attr_accessor :normal

	def initialize(position, normal)
		@position = position
		@normal = normal
	end
	
	def ==(other_vert)
		return (@position.x == other_vert.position.x && @position.y == other_vert.position.y && @position.z == other_vert.position.z)
	end
end