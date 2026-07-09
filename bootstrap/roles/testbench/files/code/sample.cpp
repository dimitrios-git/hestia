#include <iostream>
#include <string>
#include <vector>

namespace demo {

template <typename T>
class Stack {
public:
    void push(const T &value) { data_.push_back(value); }
    [[nodiscard]] bool empty() const noexcept { return data_.empty(); }

private:
    std::vector<T> data_{};
};

} // namespace demo

int main() {
    demo::Stack<std::string> s;
    auto msg = std::string{"hi"};
    std::cout << msg << '\n';
    return 0;
}
