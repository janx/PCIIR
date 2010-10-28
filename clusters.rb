require 'rubygems'
require 'RMagick'

include Magick

def readfile(filename)
  lines = File.readlines(filename)

  colnames = lines[0].strip().split("\t")[1..-1]
  rownames = []
  data = []

  for line in lines[1..-1]
    p = line.strip.split("\t")
    rownames << p[0]
    data << p[1..-1].map(&:to_f)
  end

  [rownames, colnames, data]
end

def rotate_matrix(data)
  new_data = []
  (0...data.size).each do |i|
    new_row = data.map { |row| row[i]}
    new_data << new_row
  end
  new_data
end

# In the present example, some blogs contain more entries or much
# longer entries than others, and will thus contain more words overall.
# The Pearson correlation will correct for this, since it really tries
# to determine how well two sets of data fit onto a straight line.
def pearson(v1, v2)
  sum1 = v1.inject(0, &:+)
  sum2 = v2.inject(0, &:+)

  sum1sq = v1.inject(0) { |s, v| s += v**2 }
  sum2sq = v2.inject(0) { |s, v| s += v**2 }

  psum = v1.zip(v2).inject(0) { |s, p| s += (p[0]*p[1]) }

  num = psum - (sum1*sum2/v1.size.to_f)
  den = Math.sqrt( (sum1sq - ((sum1**2)/v1.size.to_f)) * (sum2sq - ((sum2**2)/v1.size.to_f)) )
  return 0 if den == 0

  return 1.0-num/den
end


# The Pearson correlation works well for the blog dataset where the values
# are actual word counts. However, this dataset just has 1s and 0s for
# presence or absence, and it would be more useful to define some measure
# of overlap between the people who want two items. For this, there is
# a measure called the Tanimoto coefficient, which is the ratio of the
# intersection set (only the items that are in both sets) to the union set
# (all the items in either set).
def tanamoto(v1, v2)
  c1, c2, shr = 0, 0, 0

  v1.size.times do |i|
    c1 += 1 if v1[i] != 0
    c2 += 1 if v2[i] != 0
    shr += 1 if v1[i] != 0 && v2[i] != 0
  end

  return 1.0 - (shr.to_f/(c1+c2-shr))
end

# Each cluster in a hierarchical clustering algorithm is either a point in the tree with
# two branches, or an endpoint associated with an actual row from the dataset (in this
# case, a blog). Each cluster also contains data about its location, which is either the
# row data for the endpoints or the merged data from its two branches for other node
# types.
class Cluster
  attr_accessor :vec, :left, :right, :distance, :id

  def initialize(vec, opt={ })
    @vec = vec
    @left = opt[:left]
    @right = opt[:right]
    @distance = opt[:distance]
    @id = opt[:id]
  end
end

# The algorithm for hierarchical clustering begins by creating a group of clusters that
# are just the original items. The main loop of the function searches for the two best
# matches by trying every possible pair and calculating their correlation. The best pair
# of clusters is merged into a single cluster. The data for this new cluster is the average
# of the data for the two old clusters. This process is repeated until only one cluster
# remains.
def hcluster(rows, distance=:pearson)
  distances = Hash.new
  current_cluster_id = -1

  clusters = []
  rows.each_with_index do |row, i|
    clusters << Cluster.new(row, :id => i)
  end

  while clusters.size > 1
    lowest_pair = [0, 1]
    closest = send(distance, clusters[0].vec, clusters[1].vec)

    0.upto(clusters.size-1) do |i|
      (i+1).upto(clusters.size-1) do |j|
        key = [clusters[i].id, clusters[j].id]
        distances[key] ||= send(distance, clusters[i].vec, clusters[j].vec)

        if distances[key] < closest
          p distances[key]
          closest = distances[key]
          lowest_pair = [i, j]
        end
      end
    end

    merged_vec = clusters[lowest_pair[0]].vec.zip(clusters[lowest_pair[1]].vec).inject([]) do |v, p|
      v << ((p[0]+p[1])/2.0)
    end

    new_cluster = Cluster.new(merged_vec, :left => clusters[lowest_pair[0]], :right => clusters[lowest_pair[1]], :distance => closest, :id => current_cluster_id)

    current_cluster_id -= 1
    clusters.delete_at lowest_pair[1]
    clusters.delete_at lowest_pair[0]
    clusters << new_cluster
  end

  return clusters.first
end

def print_cluster(cluster, opt={ })
  indent = opt[:indent] || 0
  indent.times { print ' ' }

  if cluster.id < 0
    print '-'
  else
    if opt[:labels]
      print opt[:labels][cluster.id]
    else
      print cluster.id
    end
  end

  print "\n"
  opt[:indent] = indent + 1
  print_cluster(cluster.left, opt) if cluster.left
  print_cluster(cluster.right, opt) if cluster.right
end

def kcluster(rows, distance=:pearson, k=4)
  return unless rows.size > 0
  ranges = (0...rows.first.size).map {|i|
    rows_at_i = rows.map {|r| r[i]}
    [rows_at_i.min, rows_at_i.max]
  }

  clusters = (0...k).map {|j|
    (0...rows.first.size).map {|i|
      rand*(ranges[i][1]-ranges[i][0]) + ranges[i][0]
    }
  }

  last_matches = nil
  best_matches = nil
  100.times do |t|
    puts "Iteration #{t}"

    # Quiz: best_matches = Array.new(k, []) doesn't work here
    # do u know why? ;)
    best_matches = []
    k.times { best_matches << [] }

    rows.each_with_index do |row, j|
      best_match = 0
      best_match_score = 99999

      k.times do |i|
        d = send(distance, clusters[i], row)
        if d < best_match_score
          best_match = i
          best_match_score = d
        end
      end

      best_matches[best_match] << j
    end

    break if best_matches == last_matches
    last_matches = best_matches

    k.times do |i|
      avgs = Array.new(rows.first.size, 0.0)

      if best_matches[i].size > 0
        best_matches[i].each do |row_id|
          rows[row_id].each_with_index do |v, j|
            avgs[j] += v
          end
        end

        avgs.map {|v| v /= best_matches[i].size}

        clusters[i] = avgs
      end
    end
  end

  best_matches
end

# run main in your irb
def main
  blognames,words,data=readfile('blogdata.txt')
#  data = rotate_matrix(data)
  cluster = hcluster(data)
#  print_cluster cluster, :labels => blognames
  draw_dendrogram(cluster, blognames)
end

def kmeans_main
  blognames,words,data=readfile('blogdata.txt')
  cluster = kcluster(data, :pearson, 10)
  p cluster.map {|ids| ids.inject([]) {|names, id| names << blognames[id]; names}}
end

def zebo_main
  wants,people,data=readfile('zebo.txt')
  cluster = hcluster(data,:tanamoto)
  draw_dendrogram(cluster,wants)
end

def get_height(cluster)
  return 1 unless cluster.left || cluster.right
  return get_height(cluster.left) + get_height(cluster.right)
end

def get_depth(cluster)
  return 0 unless cluster.left || cluster.right
  result = [get_depth(cluster.left), get_depth(cluster.right)].max + cluster.distance
end

def draw_dendrogram(cluster, labels, jpeg='clusters.jpg')
  h = get_height(cluster) * 20
  w = 1200
  depth = get_depth(cluster)

  scaling = (w-150).to_f/depth

  image = Image.new(w, h) {
    self.background_color = "white"
  }

  gc = Draw.new
  gc.fill("#ff0000")
  gc.line(0, h/2, 10, h/2)

  draw_node(gc, cluster, 10, h/2, scaling, labels)

  gc.draw(image)
  image.display
end

def draw_node(draw, cluster, x, y, scaling, labels)
  if cluster.id < 0
    h1 = get_height(cluster.left) * 20
    h2 = get_height(cluster.right) * 20

    top = y - (h1+h2)/2
    bottom = y + (h1+h2)/2

    # line length
    ll = cluster.distance*scaling

    draw.fill("#ff0000")
    # Vertical line from this cluster to children
    draw.line(x, top+h1/2, x, bottom-h2/2)
    # Horizontal line to left item
    draw.line(x, top+h1/2, x+ll, top+h1/2)
    # Horizontal line to right item
    draw.line(x, bottom-h2/2, x+ll, bottom-h2/2)

    draw_node(draw, cluster.left, x+ll, top+h1/2, scaling, labels)
    draw_node(draw, cluster.right, x+ll, bottom-h2/2, scaling, labels)
  else
    draw.fill("#000000")
    draw.text(x+5, y, labels[cluster.id])
  end
end
