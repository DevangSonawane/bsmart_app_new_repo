Google Maps URL to use

https://www.google.com/maps/search/?api=1&query=ENCODED_ADDRESS&query_place_id=PLACE_ID
Example:


https://www.google.com/maps/search/?api=1&query=Anand+Sagar+Building+Mumbai&query_place_id=ChIJwe1EZjDG5zs...
Frontend Code
React / React Native Web:


// When rendering the location on a post
{post.location && (
  <a
    href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(post.location.fullText)}&query_place_id=${post.location.placeId}`}
    target="_blank"
    rel="noopener noreferrer"
    style={{ color: '#4A90D9', textDecoration: 'none' }}
  >
    📍 {post.location.name}
  </a>
)}
React Native (mobile app):


import { Linking, TouchableOpacity, Text } from 'react-native';

const openMap = (location) => {
  const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(location.fullText)}&query_place_id=${location.placeId}`;
  Linking.openURL(url);
};

<TouchableOpacity onPress={() => openMap(post.location)}>
  <Text style={{ color: '#4A90D9' }}>
    📍 {post.location.name}
  </Text>
</TouchableOpacity>
What happens when tapped
Device	Opens
Android	Google Maps app directly
iPhone	Google Maps app (if installed) or browser Maps
Web browser	Google Maps website
Make sure your post object has this shape from the API:


"location": {
  "placeId":  "ChIJwe1EZjDG5zsRaYxkjY_tpF0",
  "name":     "Anand Sagar Building",
  "address":  "VSNL Colony, Mahim, Mumbai",
  "fullText": "Anand Sagar Building, VSNL Colony, Mahim, Mumbai, Maharashtra, India"
}
If your post model doesn't have placeId yet, tell me and I'll add it to the backend.
ani hai tasa tu tya location click kela post card var ya ajun kute tr tyala google map la gheun jyach