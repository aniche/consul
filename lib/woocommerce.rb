require "woocommerce_api"

woocommerce = WooCommerce::API.new(
  "https://www.kolhaam.org.il",
  "ck_205529e492b048e267941e07f13786debc7aa9a5",#ck_b730278f9da7890772b9a9261bba4a1c00611a7e",
  "cs_235fb605f04b86f90dc7e1f3b7c34e03d7aa2e24",
  {
    wp_api: true,
    version: "wc/v1",
     query_string_auth:true   
# version: "v3"
    #verify_ssl: false 
  }
)

email = "yoav.lip@gmail.com"
email = "uri.lazar@gmail.com"
#puts woocommerce.get("customers/28").parsed_response
puts woocommerce.get("customers?filter[meta]=true&search=" + email).parsed_response
puts "all ----------"
all =  woocommerce.get("customers?per_page=100&orderby=id").parsed_response
puts all.length
puts all
all.each do |a|
  print a["billing"]["company"] 
  print " " + a["id"].to_s  + " " 
  print  a["email"] + " "
  puts "032843104" ==  a["billing"]["company"]
end
