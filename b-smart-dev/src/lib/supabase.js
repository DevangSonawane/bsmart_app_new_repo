import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ctjzgimqvxgttepxsqig.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0anpnaW1xdnhndHRlcHhzcWlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1MTM4MjAsImV4cCI6MjA4NTA4OTgyMH0.XZ4bfERi9fJYvTXAy9y6NLc3lo975wbFMUq5j8LPPs4';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
