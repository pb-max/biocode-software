/**
 * 按碱基位点统计 mean(Q)（Phred+33），输出 CSV，供 Quality score along reads 绘图。
 * 同时输出 qc.summary.csv，包含 Raw Reads、Raw Bases、Q30%、GC% 等统计信息。
 *
 * 用法：
 *   ./plot_mean_quality_from_fastq [R1.fastq.gz R2.fastq.gz]
 *   无参数时自动找当前目录唯一的 R1/R2 对
 * 输出：
 *   ./output/<sample>_mean_q_by_position.csv
 *   ./output/qc.summary.csv
 *   标准输出：sample\tR1_len
 */
#include <zlib.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <dirent.h>
#include <fstream>
#include <iostream>
#include <regex>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr int kMaxQ = 60;
constexpr size_t kLineBuf = 1 << 20;
constexpr uint64_t kProgressEvery = 5000000ULL;  // 每5M reads报告一次

bool ends_with(const std::string& s, const std::string& suf) {
  return s.size() >= suf.size() &&
         s.compare(s.size() - suf.size(), suf.size(), suf) == 0;
}

bool is_fastq_name(const std::string& name) {
  return ends_with(name, ".fastq") || ends_with(name, ".fastq.gz") ||
         ends_with(name, ".fq") || ends_with(name, ".fq.gz") ||
         ends_with(name, ".FASTQ") || ends_with(name, ".FASTQ.GZ") ||
         ends_with(name, ".FQ") || ends_with(name, ".FQ.GZ");
}

int classify_read_end(const std::string& name) {
  std::regex r1(R"(\.R1\b|\.r1\b|\.1\.)");
  std::regex r2(R"(\.R2\b|\.r2\b|\.2\.)");
  if (std::regex_search(name, r1)) return 1;
  if (std::regex_search(name, r2)) return 2;
  return 0;
}

std::string basename_only(const std::string& path) {
  auto pos = path.find_last_of("/\\");
  return pos == std::string::npos ? path : path.substr(pos + 1);
}

std::string infer_sample_name(const std::string& path) {
  std::string base = basename_only(path);
  std::smatch m;
  std::regex re(R"(^(.+?)\.(R[12]|r[12]|1|2)\b)");
  if (std::regex_search(base, m, re)) return m[1].str();
  auto dot = base.find('.');
  return dot == std::string::npos ? base : base.substr(0, dot);
}

std::vector<std::string> find_default_fastqs(const std::string& cwd = ".") {
  DIR* dir = opendir(cwd.c_str());
  if (!dir) {
    std::cerr << "无法打开目录: " << cwd << "\n";
    std::exit(1);
  }
  std::vector<std::string> names;
  while (dirent* ent = readdir(dir)) {
    std::string name = ent->d_name;
    if (name == "." || name == "..") continue;
    if (is_fastq_name(name)) names.push_back(name);
  }
  closedir(dir);
  std::sort(names.begin(), names.end());

  std::vector<std::string> r1, r2;
  for (const auto& n : names) {
    int end = classify_read_end(n);
    if (end == 1) r1.push_back(n);
    else if (end == 2) r2.push_back(n);
  }
  if (r1.size() == 1 && r2.size() == 1) {
    return {cwd + "/" + r1[0], cwd + "/" + r2[0]};
  }
  if (names.size() == 1) {
    return {cwd + "/" + names[0]};
  }
  std::cerr << "当前目录无法识别唯一的 R1/R2 fastq 对。\n";
  std::exit(1);
}

struct PosStats {
  std::vector<double> sum_q;
  std::vector<uint64_t> counts;
  uint64_t total_reads = 0;
  uint64_t total_bases = 0;
  uint64_t q30_bases = 0;
  uint64_t gc_bases = 0;

  void ensure(size_t L) {
    if (L <= sum_q.size()) return;
    sum_q.resize(L, 0.0);
    counts.resize(L, 0);
  }

  void add_qual(const char* qual, size_t len, const char* seq = nullptr) {
    while (len > 0 && (qual[len - 1] == '\n' || qual[len - 1] == '\r')) --len;
    if (len == 0) return;
    ensure(len);
    total_bases += len;
    for (size_t i = 0; i < len; ++i) {
      int q = static_cast<unsigned char>(qual[i]) - 33;
      if (q < 0) q = 0;
      if (q > kMaxQ) q = kMaxQ;
      sum_q[i] += q;
      counts[i] += 1;
      if (q >= 30) q30_bases++;
    }
    // 统计 GC 含量
    if (seq) {
      for (size_t i = 0; i < len; ++i) {
        char c = seq[i];
        if (c == 'G' || c == 'C') gc_bases++;
      }
    }
  }

  std::vector<double> mean_q() const {
    std::vector<double> out(sum_q.size(), 0.0);
    for (size_t i = 0; i < sum_q.size(); ++i) {
      if (counts[i] == 0) continue;
      out[i] = sum_q[i] / static_cast<double>(counts[i]);
    }
    return out;
  }
};

PosStats process_fastq(const std::string& path) {
  gzFile fp = gzopen(path.c_str(), "rb");
  if (!fp) {
    std::cerr << "无法打开: " << path << "\n";
    std::exit(1);
  }
  gzbuffer(fp, 1 << 22);  // 4MB 缓冲区

  PosStats stats;
  std::vector<char> tmp(kLineBuf);
  std::vector<char> qual_buf(kLineBuf);
  std::vector<char> seq_buf(kLineBuf);
  uint64_t n_reads = 0;
  auto t0 = std::chrono::steady_clock::now();
  std::string name = basename_only(path);

  while (true) {
    if (!gzgets(fp, tmp.data(), static_cast<int>(tmp.size()))) break;  // @header
    if (!gzgets(fp, seq_buf.data(), static_cast<int>(seq_buf.size()))) break;  // sequence
    if (!gzgets(fp, tmp.data(), static_cast<int>(tmp.size()))) break;  // +
    if (!gzgets(fp, qual_buf.data(), static_cast<int>(qual_buf.size()))) break;  // quality
    stats.add_qual(qual_buf.data(), std::strlen(qual_buf.data()), seq_buf.data());
    stats.total_reads++;
    ++n_reads;
    if (n_reads % kProgressEvery == 0) {
      auto sec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
      std::cerr << "[...] " << name << ": " << n_reads << " reads, " << static_cast<int>(sec)
                << "s\n";
    }
  }
  gzclose(fp);

  auto sec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  std::cerr << "[OK] " << name << ": reads=" << n_reads << ", len≈" << stats.sum_q.size()
            << ", " << static_cast<int>(sec) << "s\n";
  if (n_reads == 0) {
    std::cerr << "未读到任何 read: " << path << "\n";
    std::exit(1);
  }
  return stats;
}

void write_mean_q_csv(const std::string& path,
                      const std::vector<double>& q1,
                      const std::vector<double>& q2) {
  std::ofstream out(path);
  if (!out) {
    std::cerr << "无法写入: " << path << "\n";
    std::exit(1);
  }
  out << "position_bp,mean_quality,read_end\n";
  out.setf(std::ios::fixed);
  out.precision(6);
  for (size_t i = 0; i < q1.size(); ++i) {
    out << (i + 1) << "," << q1[i] << ",R1\n";
  }
  for (size_t i = 0; i < q2.size(); ++i) {
    out << (q1.size() + i + 1) << "," << q2[i] << ",R2\n";
  }
}

void write_qc_summary_csv(const std::string& path,
                           const std::string& sample,
                           const PosStats& r1_stats,
                           const PosStats& r2_stats) {
  std::ofstream out(path);
  if (!out) {
    std::cerr << "无法写入: " << path << "\n";
    std::exit(1);
  }
  
  uint64_t total_reads = r1_stats.total_reads + r2_stats.total_reads;
  uint64_t total_bases = r1_stats.total_bases + r2_stats.total_bases;
  uint64_t q30_bases = r1_stats.q30_bases + r2_stats.q30_bases;
  uint64_t gc_bases = r1_stats.gc_bases + r2_stats.gc_bases;
  
  double q30_rate = total_bases > 0 ? (100.0 * q30_bases / total_bases) : 0.0;
  double gc_rate = total_bases > 0 ? (100.0 * gc_bases / total_bases) : 0.0;
  
  out << "Sample,Raw Reads(G),Raw Base(G),Q30(%),GC(%)\n";
  out << sample << ",";
  // 格式化数字，每3位加逗号，用引号包裹避免CSV解析歧义
  auto format_num = [](uint64_t n) -> std::string {
    std::string s = std::to_string(n);
    int pos = s.size() - 3;
    while (pos > 0) {
      s.insert(pos, ",");
      pos -= 3;
    }
    return "\"" + s + "\"";  // 用双引号包裹
  };
  out << format_num(total_reads) << ",";
  out << format_num(total_bases) << ",";
  out.setf(std::ios::fixed);
  out.precision(4);
  out << q30_rate << "," << gc_rate << "\n";
}

}  // namespace

int main(int argc, char** argv) {
  std::vector<std::string> inputs;
  if (argc >= 2) {
    for (int i = 1; i < argc; ++i) inputs.emplace_back(argv[i]);
  } else {
    inputs = find_default_fastqs(".");
  }

  std::string sample = infer_sample_name(inputs[0]);
  std::string outdir = "./output";
  std::string csv_path = outdir + "/" + sample + "_mean_q_by_position.csv";
  std::string qc_csv_path = outdir + "/qc.summary.csv";
  for (const auto& p : inputs) std::cerr << " " << basename_only(p);
  std::cerr << "\n";

  PosStats r1_stats, r2_stats;
  std::vector<double> q1, q2;
  
  if (inputs.size() >= 2) {
    // 多线程并行处理 R1 和 R2
    std::thread t1([&]() { r1_stats = process_fastq(inputs[0]); });
    std::thread t2([&]() { r2_stats = process_fastq(inputs[1]); });
    t1.join();
    t2.join();
    q1 = r1_stats.mean_q();
    q2 = r2_stats.mean_q();
  } else {
    r1_stats = process_fastq(inputs[0]);
    q1 = r1_stats.mean_q();
  }

  write_mean_q_csv(csv_path, q1, q2);
  write_qc_summary_csv(qc_csv_path, sample, r1_stats, r2_stats);
  std::cout << sample << "\t" << q1.size() << "\n";
  return 0;
}
