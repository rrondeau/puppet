#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'puppet/parser/e4_parser_adapter'


# relative to this spec file (./) does not work as this file is loaded by rspec
#require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include PuppetSpec::Pops
  include PuppetSpec::Scope
  before(:each) do
    Puppet[:strict_variables] = true
  end

  let(:parser) { Puppet::Pops::Parser::EvaluatingParser::Transitional.new }
  let(:node) { 'node.example.com' }
  let(:scope) { s = create_test_scope_for_node(node); s }
  types = Puppet::Pops::Types::TypeFactory

  context "When evaluator evaluates literals" do
    {
      "1"             => 1,
      "010"           => 8,
      "0x10"          => 16,
      "3.14"          => 3.14,
      "0.314e1"       => 3.14,
      "31.4e-1"       => 3.14,
      "'1'"           => '1',
      "'banana'"      => 'banana',
      '"banana"'      => 'banana',
      "banana"        => 'banana',
      "banana::split" => 'banana::split',
      "false"         => false,
      "true"          => true,
      "Array"         => types.array_of_data(),
      "/.*/"          => /.*/
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end
  end

  context "When the evaluator evaluates Lists and Hashes" do
    {
      "[]"                                              => [],
      "[1,2,3]"                                         => [1,2,3],
      "[1,[2.0, 2.1, [2.2]],[3.0, 3.1]]"                => [1,[2.0, 2.1, [2.2]],[3.0, 3.1]],
      "[2 + 2]"                                         => [4],
      "[1,2,3] == [1,2,3]"                              => true,
      "[1,2,3] != [2,3,4]"                              => true,
      "[1,2,3] == [2,2,3]"                              => false,
      "[1,2,3] != [1,2,3]"                              => false,
      "[1,2,3][2]"                                      => 3,
      "[1,2,3] + [4,5]"                                 => [1,2,3,4,5],
      "[1,2,3] + [[4,5]]"                               => [1,2,3,[4,5]],
      "[1,2,3] + {'a' => 1, 'b'=>2}"                    => [1,2,3,['a',1],['b',2]],
      "[1,2,3] + 4"                                     => [1,2,3,4],
      "[1,2,3] << [4,5]"                                => [1,2,3,[4,5]],
      "[1,2,3] << {'a' => 1, 'b'=>2}"                   => [1,2,3,{'a' => 1, 'b'=>2}],
      "[1,2,3] << 4"                                    => [1,2,3,4],
      "[1,2,3,4] - [2,3]"                               => [1,4],
      "[1,2,3,4] - [2,5]"                               => [1,3,4],
      "[1,2,3,4] - 2"                                   => [1,3,4],
      "[1,2,3,[2],4] - 2"                               => [1,3,[2],4],
      "[1,2,3,[2,3],4] - [[2,3]]"                       => [1,2,3,4],
      "[1,2,3,3,2,4,2,3] - [2,3]"                       => [1,4],
      "[1,2,3,['a',1],['b',2]] - {'a' => 1, 'b'=>2}"    => [1,2,3],
      "[1,2,3,{'a'=>1,'b'=>2}] - [{'a' => 1, 'b'=>2}]"  => [1,2,3],
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "[1,2,3][a]" => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    {
      "{}"                                       => {},
      "{'a'=>1,'b'=>2}"                          => {'a'=>1,'b'=>2},
      "{'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}"        => {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}},
      "{'a'=> 2 + 2}"                            => {'a'=> 4},
      "{'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2}"   => true,
      "{'a'=> 1, 'b'=>2} != {'x'=> 1, 'b'=>2}"   => true,
      "{'a'=> 1, 'b'=>2} == {'a'=> 2, 'b'=>3}"   => false,
      "{'a'=> 1, 'b'=>2} != {'a'=> 1, 'b'=>2}"   => false,
      "{a => 1, b => 2}[b]"                      => 2,
      "{2+2 => sum, b => 2}[4]"                  => 'sum',
      "{'a'=>1, 'b'=>2} + {'c'=>3}"              => {'a'=>1,'b'=>2,'c'=>3},
      "{'a'=>1, 'b'=>2} + {'b'=>3}"              => {'a'=>1,'b'=>3},
      "{'a'=>1, 'b'=>2} + ['c', 3, 'b', 3]"      => {'a'=>1,'b'=>3, 'c'=>3},
      "{'a'=>1, 'b'=>2} + [['c', 3], ['b', 3]]"  => {'a'=>1,'b'=>3, 'c'=>3},
      "{'a'=>1, 'b'=>2} - {'b' => 3}"            => {'a'=>1},
      "{'a'=>1, 'b'=>2, 'c'=>3} - ['b', 'c']"    => {'a'=>1},
      "{'a'=>1, 'b'=>2, 'c'=>3} - 'c'"           => {'a'=>1, 'b'=>2},
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "{'a' => 1, 'b'=>2} << 1" => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When the evaluator perform comparisons" do
    {
      "'a' == 'a'"     => true,
      "'a' == 'b'"     => false,
      "'a' != 'a'"     => false,
      "'a' != 'b'"     => true,
      "'a' < 'b' "     => true,
      "'a' < 'a' "     => false,
      "'b' < 'a' "     => false,
      "'a' <= 'b'"     => true,
      "'a' <= 'a'"     => true,
      "'b' <= 'a'"     => false,
      "'a' > 'b' "     => false,
      "'a' > 'a' "     => false,
      "'b' > 'a' "     => true,
      "'a' >= 'b'"     => false,
      "'a' >= 'a'"     => true,
      "'b' >= 'a'"     => true,
      "'a' == 'A'"     => true,
      "'a' != 'A'"     => false,
      "'a' >  'A'"     => false,
      "'a' >= 'A'"     => true,
      "'A' <  'a'"     => false,
      "'A' <= 'a'"     => true,
      "1 == 1"         => true,
      "1 == 2"         => false,
      "1 != 1"         => false,
      "1 != 2"         => true,
      "1 < 2 "         => true,
      "1 < 1 "         => false,
      "2 < 1 "         => false,
      "1 <= 2"         => true,
      "1 <= 1"         => true,
      "2 <= 1"         => false,
      "1 > 2 "         => false,
      "1 > 1 "         => false,
      "2 > 1 "         => true,
      "1 >= 2"         => false,
      "1 >= 1"         => true,
      "2 >= 1"         => true,
      "1 == 1.0 "      => true,
      "1 < 1.1  "      => true,
      "'1' < 1.1"      => true,
      "1.0 == 1 "      => true,
      "1.0 < 2  "      => true,
      "'1.0' < 1.1"    => true,
      "'1.0' < 'a'"    => true,
      "'1.0' < '' "    => true,
      "'1.0' < ' '"    => true,
      "'a' > '1.0'"    => true,
      "/.*/ == /.*/ "  => true,
      "/.*/ != /a.*/"  => true,
      "true  == true " => true,
      "false == false" => true,
      "true == false"  => false,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

   {
      "'a' =~ /.*/"                     => true,
      "'a' =~ '.*'"                     => true,
      "/.*/ != /a.*/"                   => true,
      "'a' !~ /b.*/"                    => true,
      "'a' !~ 'b.*'"                    => true,
      '$x = a; a =~ "$x.*"'             => true,
      "a =~ Pattern['a.*']"             => true,
      "$x = /a.*/ a =~ $x"              => true,
      "$x = Pattern['a.*'] a =~ $x"     => true,
      "1 =~ Integer"                    => true,
      "1 !~ Integer"                    => false,
      "[1,2,3] =~ Array[Integer[1,10]]" => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "666 =~ /6/"    => :error,
      "[a] =~ /a/"    => :error,
      "{a=>1} =~ /a/" => :error,
      "/a/ =~ /a/"    => :error,
      "Array =~ /A/"  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    {
      "1 in [1,2,3]"                  => true,
      "4 in [1,2,3]"                  => false,
      "a in {x=>1, a=>2}"             => true,
      "z in {x=>1, a=>2}"             => false,
      "ana in bananas"                => true,
      "xxx in bananas"                => false,
      "/ana/ in bananas"              => true,
      "/xxx/ in bananas"              => false,
      "ANA in bananas"                => false, # ANA is a type, not a String
      "'ANA' in bananas"              => true,
      "ana in 'BANANAS'"              => true,
      "/ana/ in 'BANANAS'"            => false,
      "/ANA/ in 'BANANAS'"            => true,
      "xxx in 'BANANAS'"              => false,
      "[2,3] in [1,[2,3],4]"          => true,
      "[2,4] in [1,[2,3],4]"          => false,
      "[a,b] in ['A',['A','B'],'C']"  => true,
      "[x,y] in ['A',['A','B'],'C']"  => false,
      "a in {a=>1}"                   => true,
      "x in {a=>1}"                   => false,
      "'A' in {a=>1}"                 => true,
      "'X' in {a=>1}"                 => false,
      "a in {'A'=>1}"                 => true,
      "x in {'A'=>1}"                 => false,
      "/xxx/ in {'aaaxxxbbb'=>1}"     => true,
      "/yyy/ in {'aaaxxxbbb'=>1}"     => false,
      "15 in [1, 0xf]"                => true,
      "15 in [1, '0xf']"              => true,
      "'15' in [1, 0xf]"              => true,
      "15 in [1, 115]"                => false,
      "1 in [11, '111']"              => false,
      "'1' in [11, '111']"            => false,
      "Array[Integer] in [2, 3]"      => false,
      "Array[Integer] in [2, [3, 4]]" => true,
      "Array[Integer] in [2, [a, 4]]" => false,
      "Integer in { 2 =>'a'}"         => true,
      "Integer[5,10] in [1,5,3]"      => true,
      "Integer[5,10] in [1,2,3]"      => false,
      "Integer in {'a'=>'a'}"         => false,
      "Integer in {'a'=>1}"           => false,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    {
      'Object'  => ['Data', 'Literal', 'Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern', 'Collection',
                    'Array', 'Hash', 'CatalogEntry', 'Resource', 'Class', 'Undef', 'File', 'NotYetKnownResourceType'],

      # Note, Data > Collection is false (so not included)
      'Data'    => ['Literal', 'Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern', 'Array', 'Hash',],
      'Literal' => ['Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern'],
      'Numeric' => ['Integer', 'Float'],
      'CatalogEntry' => ['Class', 'Resource', 'File', 'NotYetKnownResourceType'],
      'Integer[1,10]' => ['Integer[2,3]'],
    }.each do |general, specials|
      specials.each do |special |
        it "should compute that #{general} > #{special}" do
          parser.evaluate_string(scope, "#{general} > #{special}", __FILE__).should == true
        end
        it "should compute that  #{special} < #{general}" do
          parser.evaluate_string(scope, "#{special} < #{general}", __FILE__).should == true
        end
        it "should compute that #{general} != #{special}" do
          parser.evaluate_string(scope, "#{special} != #{general}", __FILE__).should == true
        end
      end
    end

    {
      'Integer[1,10] > Integer[2,3]'   => true,
      'Integer[1,10] == Integer[2,3]'  => false,
      'Integer[1,10] > Integer[0,5]'   => false,
      'Integer[1,10] > Integer[1,10]'  => false,
      'Integer[1,10] >= Integer[1,10]' => true,
      'Integer[1,10] == Integer[1,10]' => true,
    }.each do |source, result|
        it "should parse and evaluate the integer range comparison expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

  end

  context "When the evaluator performs arithmetic" do
    context "on Integers" do
      {  "2+2"    => 4,
         "2 + 2"  => 4,
         "7 - 3"  => 4,
         "6 * 3"  => 18,
         "6 / 3"  => 2,
         "6 % 3"  => 0,
         "10 % 3" =>  1,
         "-(6/3)" => -2,
         "-6/3  " => -2,
         "8 >> 1" => 4,
         "8 << 1" => 16,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

    context "on Floats" do
      {
        "2.2 + 2.2"  => 4.4,
        "7.7 - 3.3"  => 4.4,
        "6.1 * 3.1"  => 18.91,
        "6.6 / 3.3"  => 2.0,
        "-(6.0/3.0)" => -2.0,
        "-6.0/3.0 "  => -2.0,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

      {
        "3.14 << 2" => :error,
        "3.14 >> 2" => :error,
        "6.6 % 3.3"  => 0.0,
        "10.0 % 3.0" =>  1.0,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
    end

    context "on strings requiring boxing to Numeric" do
      {
        "'2' + '2'"       => 4,
        "'2.2' + '2.2'"   => 4.4,
        "'0xF7' + '010'"  => 0xFF,
        "'0xF7' + '0x8'"  => 0xFF,
        "'0367' + '010'"  => 0xFF,
        "'012.3' + '010'" => 20.3,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

      {
        "'0888' + '010'"   => :error,
        "'0xWTF' + '010'"  => :error,
        "'0x12.3' + '010'" => :error,
        "'0x12.3' + '010'" => :error,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
      end
    end
  end # arithmetic

  context "When the evaluator evaluates assignment" do
    {
      "$a = 5"                     => 5,
      "$a = 5; $a"                 => 5,
      "$a = 5; $b = 6; $a"         => 5,
      "$a = $b = 5; $a == $b"      => true,
      "$a = [1,2,3]; [x].map |$x| { $a += x; $a }"      => [[1,2,3,'x']],
      "$a = [a,x,c]; [x].map |$x| { $a -= x; $a }"      => [['a','c']],
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "[a,b,c] = [1,2,3]; $a == 1 and $b == 2 and $c == 3"               => :error,
      "[a,b,c] = {b=>2,c=>3,a=>1}; $a == 1 and $b == 2 and $c == 3"      => :error,
      "$a = [1,2,3]; [x].collect |$x| { [a] += x; $a }"                  => :error,
      "$a = [a,x,c]; [x].collect |$x| { [a] -= x; $a }"                  => :error,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When the evaluator evaluates conditionals" do
    {
      "if true {5}"                     => 5,
      "if false {5}"                    => nil,
      "if false {2} else {5}"           => 5,
      "if false {2} elsif true {5}"     => 5,
      "if false {2} elsif false {5}"    => nil,
      "unless false {5}"                => 5,
      "unless true {5}"                 => nil,
      "unless true {2} else {5}"        => 5,
      "$a = if true {5} $a"                     => 5,
      "$a = if false {5} $a"                    => nil,
      "$a = if false {2} else {5} $a"           => 5,
      "$a = if false {2} elsif true {5} $a"     => 5,
      "$a = if false {2} elsif false {5} $a"    => nil,
      "$a = unless false {5} $a"                => 5,
      "$a = unless true {5} $a"                 => nil,
      "$a = unless true {2} else {5} $a"        => 5,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "case 1 { 1 : { yes } }"                               => 'yes',
      "case 2 { 1,2,3 : { yes} }"                            => 'yes',
      "case 2 { 1,3 : { no } 2: { yes} }"                    => 'yes',
      "case 2 { 1,3 : { no } 5: { no } default: { yes }}"    => 'yes',
      "case 2 { 1,3 : { no } 5: { no } }"                    => nil,
      "case 'banana' { 1,3 : { no } /.*ana.*/: { yes } }"    => 'yes',
      "case 'banana' { /.*(ana).*/: { $1 } }"                => 'ana',
      "case [1] { Array : { yes } }"                         => 'yes',
      "case [1] {
         Array[String] : { no }
         Array[Integer]: { yes }
      }"                                                     => 'yes',
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "2 ? { 1 => no, 2 => yes}"                          => 'yes',
      "3 ? { 1 => no, 2 => no}"                           => nil,
      "3 ? { 1 => no, 2 => no, default => yes }"          => 'yes',
      "3 ? { 1 => no, default => yes, 3 => no }"          => 'yes',
      "'banana' ? { /.*(ana).*/  => $1 }"                 => 'ana',
      "[2] ? { Array[String] => yes, Array => yes}"       => 'yes',
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end
  end

  context "When evaluator performs [] operations" do
    {
      "[1,2,3][0]"      => 1,
      "[1,2,3][2]"      => 3,
      "[1,2,3][3]"      => nil,
      "[1,2,3][-1]"     => 3,
      "[1,2,3][-2]"     => 2,
      "[1,2,3][-4]"     => nil,
      "[1,2,3,4][0,2]"  => [1,2],
      "[1,2,3,4][1,3]"  => [2,3,4],
      "[1,2,3,4][-2,2]"  => [3,4],
      "[1,2,3,4][-3,2]"  => [2,3],
      "[1,2,3,4][3,5]"   => [4],
      "[1,2,3,4][5,2]"   => [],
      "[1,2,3,4][0,-1]"  => [1,2,3,4],
      "[1,2,3,4][0,-2]"  => [1,2,3],
      "[1,2,3,4][0,-4]"  => [1],
      "[1,2,3,4][0,-5]"  => [],
      "[1,2,3,4][-5,2]"  => [1],
      "[1,2,3,4][-5,-3]" => [1,2],
      "[1,2,3,4][-6,-3]" => [1,2],
      "[1,2,3,4][2,-3]"  => [],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    {
      "{a=>1, b=>2, c=>3}[a]"      => 1,
      "{a=>1, b=>2, c=>3}[c]"      => 3,
      "{a=>1, b=>2, c=>3}[x]"      => nil,
      "{a=>1, b=>2, c=>3}[c,b]"    => [3,2],
      "{a=>1, b=>2, c=>3}[a,b,c]"  => [1,2,3],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    {
      "'abc'[0]"      => 'a',
      "'abc'[2]"      => 'c',
      "'abc'[-1]"     => 'c',
      "'abc'[-2]"     => 'b',
      "'abc'[-3]"     => 'a',
      "'abc'[-4]"     => '',
      "'abc'[3]"      => '',
      "abc[0]"        => 'a',
      "abc[2]"        => 'c',
      "abc[-1]"       => 'c',
      "abc[-2]"       => 'b',
      "abc[-3]"       => 'a',
      "abc[-4]"       => '',
      "abc[3]"        => '',
      "'abcd'[0,2]"   => 'ab',
      "'abcd'[1,3]"   => 'bcd',
      "'abcd'[-2,2]"  => 'cd',
      "'abcd'[-3,2]"  => 'bc',
      "'abcd'[3,5]"   => 'd',
      "'abcd'[5,2]"   => '',
      "'abcd'[0,-1]"  => 'abcd',
      "'abcd'[0,-2]"  => 'abc',
      "'abcd'[0,-4]"  => 'a',
      "'abcd'[0,-5]"  => '',
      "'abcd'[-5,2]"  => 'a',
      "'abcd'[-5,-3]" => 'ab',
      "'abcd'[-6,-3]" => 'ab',
      "'abcd'[2,-3]"  => '',
   }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    # Type operations (full set tested by tests covering type calculator)
    {
      "Array[Integer]"             => types.array_of(types.integer),
      "Hash[Integer,Integer]"      => types.hash_of(types.integer, types.integer),
      "Resource[File]"             => types.resource('File'),
      "Resource['File']"           => types.resource(types.resource('File')),
      "File[foo]"                  => types.resource('file', 'foo'),
      "File[foo, bar]"             => [types.resource('file', 'foo'), types.resource('file', 'bar')],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    # LHS where [] not supported, and missing key(s)
    {
      "Array[]"                    => :error,
      "'abc'[]"                    => :error,
      "Resource[]"                 => :error,
      "File[]"                     => :error,
      "String[]"                   => :error,
      "String[0]"                   => :error,
      "1[]"                        => :error,
      "1[0]"                        => :error,
      "3.14[]"                     => :error,
      "3.14[0]"                     => :error,
      "/.*/[]"                     => :error,
      "/.*/[0]"                     => :error,
      "$a=[1] $a[]"                => :error,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(Puppet::ParseError)
      end
    end

    context "on catalog types" do
      it "[n] gets resource parameter [n]" do
        source = "notify { 'hello': message=>'yo'} Notify[hello][message]"
        parser.evaluate_string(scope, source, __FILE__).should == 'yo'
      end

      it "[n] gets class parameter [n]" do
        source = "class wonka($produces='chocolate'){ }
           include wonka
           Class[wonka][produces]"

        # This is more complicated since it needs to run like 3.x and do an import_ast
        adapted_parser = Puppet::Parser::E4ParserAdapter.new
        adapted_parser.file = __FILE__
        ast = adapted_parser.parse(source)
        scope.known_resource_types.import_ast(ast, '')
        ast.code.safeevaluate(scope).should == 'chocolate'
      end
      # Resource default and override expressions and resource parameter access with []
      {
        "notify { id: message=>explicit} Notify[id][message]"                   => "explicit",
        "Notify { message=>by_default} notify {foo:} Notify[foo][message]"      => "by_default",
        "notify {foo:} Notify[foo]{message =>by_override} Notify[foo][message]" => "by_override",
      }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

      # Resource default and override expressions and resource parameter access error conditions
      {
        "notify { xid: message=>explicit} Notify[id][message]"  => /Resource not found/,
        "notify { id: message=>explicit} Notify[id][mustard]"   => /does not have a parameter called 'mustard'/,
      }.each do |source, result|
        it "should parse '#{source}' and raise error matching #{result}" do
          expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(result)
        end
      end
    end
  # end [] operations
  end

  context "When the evaluator performs boolean operations" do
    {
      "true and true"   => true,
      "false and true"  => false,
      "true and false"  => false,
      "false and false" => false,
      "true or true"    => true,
      "false or true"   => true,
      "true or false"   => true,
      "false or false"  => false,
      "! true"          => false,
      "!! true"         => true,
      "!! false"        => false,
      "! 'x'"           => false,
      "! ''"            => true,
      "! undef"         => true,
      "! [a]"           => false,
      "! []"            => false,
      "! {a=>1}"        => false,
      "! {}"            => false,
      "true and false and '0xwtf' + 1"  => false,
      "false or true  or '0xwtf' + 1"  => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "false || false || '0xwtf' + 1"   => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluator performs calls" do
    let(:populate) do
      parser.evaluate_string(scope, "$a = 10 $b = [1,2,3]")
    end

    {
      'sprintf( "x%iy", $a )'                 => "x10y",
      '"x%iy".sprintf( $a )'                  => "x10y",
      '$b.reduce |$memo,$x| { $memo + $x }'   => 6,
      'reduce($b) |$memo,$x| { $memo + $x }'  => 6,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluator performs string interpolation" do
    let(:populate) do
      parser.evaluate_string(scope, "$a = 10 $b = [1,2,3]")
    end

    {
      '"value is $a yo"'                      => "value is 10 yo",
      '"value is \$a yo"'                     => "value is $a yo",
      '"value is ${a} yo"'                    => "value is 10 yo",
      '"value is \${a} yo"'                   => "value is ${a} yo",
      '"value is ${$a} yo"'                   => "value is 10 yo",
      '"value is ${$a*2} yo"'                 => "value is 20 yo",
      '"value is ${sprintf("x%iy",$a)} yo"'   => "value is x10y yo",
      '"value is ${"x%iy".sprintf($a)} yo"'   => "value is x10y yo",
      '"value is ${[1,2,3]} yo"'              => "value is [1, 2, 3] yo",
      '"value is ${{a=>1,b=>2}} yo"'          => "value is {a => 1, b => 2} yo",
      '"value is ${/.*/} yo"'                 => "value is /.*/ yo",
      '$x = undef "value is $x yo"'           => "value is  yo",
      '$x = default "value is $x yo"'         => "value is default yo",
      '$x = Array[Integer] "value is $x yo"'  => "value is Array[Integer] yo",
      '"value is ${Array[Integer]} yo"'       => "value is Array[Integer] yo",
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluating variables" do
    context "that are non existing an error is raised for" do
      it "unqualified variable" do
        expect { parser.evaluate_string(scope, "$quantum_gravity", __FILE__) }.to raise_error(/Unknown variable/)
      end

      it "qualified variable" do
        expect { parser.evaluate_string(scope, "$quantum_gravity::graviton", __FILE__) }.to raise_error(/Unknown variable/)
      end
    end
  end

  context "When evaluating relationships" do
    it 'should form a relation with ->' do
      source = "File[a] -> File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      scope.compiler.should have_relationship(['File', 'a', '->', 'File', 'b'])
    end

    it 'should form a relation with <-' do
      source = "File[a] <- File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      scope.compiler.should have_relationship(['File', 'b', '->', 'File', 'a'])
    end

    it 'should form a relation with <-' do
      source = "File[a] <~ File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      scope.compiler.should have_relationship(['File', 'b', '~>', 'File', 'a'])
    end
  end

  matcher :have_relationship do |expected|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |compiler|
      op_name = {'->' => :relationship, '~>' => :subscription}
      compiler.relationships.any? do | relation |
        relation.source.type == expected[0] &&
        relation.source.title == expected[1] &&
        relation.type == op_name[expected[2]] &&
        relation.target.type == expected[3] &&
        relation.target.title == expected[4]
      end
    end

    failure_message_for_should do |actual|
      "Relationship #{expected[0]}[#{expected[1]}] #{expected[2]} #{expected[3]}[#{expected[4]}] but was unknown to compiler"
    end
  end

end
